//
//  TranslationView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData
import PhotosUI
import Translation

struct TranslationView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var service = TranslationService()
    @State private var audioService = AudioService()
    @State private var aiService = AIAssistantService()
    @State private var historyService = HistoryService()
    @State private var tagService = TagService()
    @Binding var inputText: String
    @State private var translations: [TranslationResult] = []
    @State private var activePriorityLanguage: Locale.Language?
    @State private var isTranslating = false
    @State private var loadingLanguages: Set<Locale.Language> = []
    @State private var showImageTranslation = false
    @State private var showSettings = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    // Computed property - auto-use all installed languages
    private var selectedLanguages: Set<Locale.Language> {
        installedLanguages
    }

    // Computed binding that only shows sheet when image is available
    private var showImageTranslationBinding: Binding<Bool> {
        Binding(
            get: { showImageTranslation && selectedImage != nil },
            set: { newValue in
                showImageTranslation = newValue
                if !newValue {
                    // Clear image when sheet is dismissed
                    selectedImage = nil
                    selectedPhotoItem = nil
                }
            }
        )
    }
    @State private var debounceTask: Task<Void, Never>?
    @State private var detectedLanguage: String?
    @State private var detectedLanguages: [(language: Locale.Language, confidence: Double, isDownloaded: Bool)] = []
    @State private var selectedSourceLanguage: Locale.Language? = nil
    @State private var currentSourceLanguage: Locale.Language? = nil
    @State private var showSourceLanguagePicker = false
    @State private var installedLanguages: Set<Locale.Language> = []
    @State private var sourceRomanization: String?
    @State private var errorMessage: ErrorMessage?
    @State private var errorTrigger = UUID()
    @FocusState private var isInputFocused: Bool
    @AppStorage("defaultSpeechRate") private var speechRate: Double = 0.5

    // Feature toggles
    @AppStorage("includeRomanization") private var includeRomanization: Bool = true
    @AppStorage("autoSaveToHistory") private var autoSaveToHistory: Bool = true

    private let debounceDelay: Duration = .milliseconds(300)

    init(initialText: Binding<String>) {
        _inputText = initialText
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Lingko")
                .navigationBarTitleDisplayMode(.inline)
                .errorBanner($errorMessage, onRetry: retryLastTranslation)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings")
                    }

                    ToolbarItemGroup(placement: .topBarTrailing) {
                        PhotosPicker(
                            selection: $selectedPhotoItem,
                            matching: .images
                        ) {
                            Label("Image Translation", systemImage: "photo")
                        }
                    }

                    ToolbarItem(placement: .keyboard) {
                        Button {
                            isInputFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                        }
                    }
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
                }
                .sheet(isPresented: $showSourceLanguagePicker) {
                    SourceLanguagePickerView(
                        detectedLanguages: detectedLanguages,
                        installedLanguages: installedLanguages,
                        selectedSourceLanguage: $selectedSourceLanguage,
                        onAutoDetect: {
                            selectedSourceLanguage = nil
                            if !inputText.isEmpty {
                                handleTextChange(inputText)
                            }
                        }
                    )
                }
                .sheet(isPresented: showImageTranslationBinding) {
                    // The binding guarantees selectedImage is non-nil when sheet is shown
                    if let image = selectedImage {
                        CameraTranslationView(
                            initialImage: image,
                            selectedLanguages: selectedLanguages,
                            autoSaveToHistory: autoSaveToHistory,
                            historyService: historyService,
                            aiService: aiService,
                            tagService: tagService,
                            modelContext: modelContext
                        )
                    } else {
                        // Fallback empty view (should never happen due to binding)
                        EmptyView()
                    }
                }
                .onChange(of: selectedSourceLanguage) { _, newLanguage in
                    // Update current source language when manually selected
                    if let newLanguage = newLanguage {
                        currentSourceLanguage = newLanguage

                        // If active priority language is same as new source, switch to another
                        if activePriorityLanguage == newLanguage {
                            let availableTargets = selectedLanguages.filter { $0 != newLanguage }
                            activePriorityLanguage = availableTargets.sorted(by: { l1, l2 in
                                (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                                (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                            }).first
                        }
                    } else if !inputText.isEmpty {
                        // If auto-detect is selected, trigger translation to recalculate
                        handleTextChange(inputText)
                    }
                }
                .onChange(of: selectedPhotoItem) { oldItem, newItem in
                    // Clear state when picker is dismissed without selection
                    if newItem == nil {
                        selectedImage = nil
                        showImageTranslation = false
                        return
                    }
                    
                    // Only process if we have a new item
                    guard let newItem = newItem else { return }
                    
                    // Load the image
                    Task {
                        await loadImage(from: newItem)
                    }
                }
                .onDisappear {
                    audioService.stop()
                }
                .task {
                    await loadInstalledLanguages()

                    // Initialize active priority language on first load
                    if activePriorityLanguage == nil && !selectedLanguages.isEmpty {
                        activePriorityLanguage = selectedLanguages.sorted(by: { l1, l2 in
                            (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                            (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                        }).first
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: translations.count)
                .sensoryFeedback(.error, trigger: errorTrigger)
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Input section
            inputSection

            Divider()

            // Language selector section (only show if languages are selected and text is not empty)
            if !selectedLanguages.isEmpty && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                languageSelectorSection
                Divider()
            }

            // Results section
            resultsSection
        }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Source language chip selector
            SourceLanguageChipRow(
                availableLanguages: Array(selectedLanguages).sorted(by: { l1, l2 in
                    (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                    (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                }),
                selectedLanguage: selectedSourceLanguage,
                onLanguageSelected: { language in
                    selectedSourceLanguage = language
                },
                onAutoSelected: {
                    selectedSourceLanguage = nil
                    if !inputText.isEmpty {
                        handleTextChange(inputText)
                    }
                }
            )

            ZStack(alignment: .topLeading) {
                TextEditor(text: $inputText)
                    .frame(minHeight: 100, maxHeight: 200)
                    .background(Color(.systemBackground))
                    .focused($isInputFocused)
                    .onChange(of: inputText) { _, newValue in
                        handleTextChange(newValue)
                    }

                if inputText.isEmpty {
                    Text("Enter text")
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }

            // Source romanization
            if let romanization = sourceRomanization {
                HStack(spacing: 6) {
                    Image(systemName: "textformat.abc")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(romanization)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .textSelection(.enabled)
                }
            }
        }
        .padding()
    }

    // MARK: - Language Selector Section

    @ViewBuilder
    private var languageSelectorSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Filter out source language from target languages
                let targetLanguages = selectedLanguages.filter { $0 != currentSourceLanguage }

                ForEach(Array(targetLanguages).sorted(by: { l1, l2 in
                    (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                    (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                }), id: \.minimalIdentifier) { language in
                    let isActive = activePriorityLanguage?.minimalIdentifier == language.minimalIdentifier
                    let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier

                    Button {
                        // Set this language as the active priority language
                        activePriorityLanguage = language
                    } label: {
                        Text(languageName)
                            .font(.subheadline)
                            .fontWeight(isActive ? .semibold : .regular)
                            .foregroundStyle(isActive ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isActive ? Color.accentColor : Color(.secondarySystemFill))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyStateView(configuration: .translationEmpty)
                .transition(.opacity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Show only the active priority language's translation
                    if let activeLanguage = activePriorityLanguage {
                        if let activeTranslation = translations.first(where: { $0.language == activeLanguage }) {
                            TranslationResultRow(
                                result: activeTranslation,
                                audioService: audioService,
                                aiService: aiService,
                                speechRate: Float(speechRate)
                            )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.9).combined(with: .opacity),
                                removal: .opacity
                            ))
                        } else if loadingLanguages.contains(activeLanguage) {
                            // Show skeleton loader for active language being translated
                            SkeletonCard()
                                .transition(.asymmetric(
                                    insertion: .scale(scale: 0.9).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Translation Logic

    private func handleTextChange(_ text: String) {
        // Cancel previous debounce task
        debounceTask?.cancel()

        // Clear translations if text is empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translations = []
            detectedLanguage = nil
            detectedLanguages = []
            selectedSourceLanguage = nil
            currentSourceLanguage = nil
            sourceRomanization = nil
            isTranslating = false
            loadingLanguages = []
            return
        }

        // Create new debounced task for translation
        debounceTask = Task {
            do {
                try await Task.sleep(for: debounceDelay)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                await performTranslation(text: text)
            } catch {
                // Task was cancelled or sleep failed
            }
        }
    }

    private func performTranslation(text: String) async {
        isTranslating = true
        errorMessage = nil

        do {
            // Detect languages with preference for user-selected languages
            let detected = service.detectLanguages(
                for: text,
                preferredLanguages: selectedLanguages,
                installedLanguages: installedLanguages,
                maxResults: 5
            )
            detectedLanguages = detected
            
            // Determine source language with priority:
            // 1. Manual override (if set)
            // 2. Highest confidence language that's user-selected (doesn't need to be downloaded)
            // 3. Highest confidence detected language
            // Note: Source language doesn't need to be downloaded, only target languages do
            let sourceLanguage: Locale.Language?
            if let manual = selectedSourceLanguage {
                sourceLanguage = manual
            } else {
                // Find best language that's also user-selected
                let detectedAndSelected = detected.first { result in
                    selectedLanguages.contains(result.language)
                }
                
                if let best = detectedAndSelected {
                    sourceLanguage = best.language
                } else {
                    // Fallback to any detected language
                    sourceLanguage = detected.first?.language
                }
            }
            
            // Update display for primary detected language
            if let primary = detected.first {
                detectedLanguage = Locale.current.localizedString(forLanguageCode: primary.language.minimalIdentifier)
                    ?? primary.language.minimalIdentifier
            }

            // Check if languages are selected
            guard !selectedLanguages.isEmpty else {
                throw TranslationError.invalidConfiguration
            }
            
            // Check if we have a valid source language
            guard let sourceLanguage = sourceLanguage else {
                throw TranslationError.detectionFailed
            }

            // Update current source language for UI display
            currentSourceLanguage = sourceLanguage

            // If active priority language is same as source, switch to another available target
            if activePriorityLanguage == sourceLanguage {
                let availableTargets = selectedLanguages.filter { $0 != sourceLanguage && installedLanguages.contains($0) }
                activePriorityLanguage = availableTargets.sorted(by: { l1, l2 in
                    (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                    (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                }).first
            }

            // Filter target languages to only downloaded ones
            let downloadedTargetLanguages = selectedLanguages.filter { installedLanguages.contains($0) }

            guard !downloadedTargetLanguages.isEmpty else {
                // Collect missing language names
                let missingLanguages = selectedLanguages.compactMap { language in
                    Locale.current.localizedString(forLanguageCode: language.minimalIdentifier)
                }
                throw TranslationError.missingLanguagePacks(missingLanguages)
            }

            // Set loading state for all target languages (excluding source)
            loadingLanguages = downloadedTargetLanguages.filter { $0 != sourceLanguage }

            // Clear old translations to prepare for new ones
            translations = []

            // Perform translation with feature flags and progressive updates
            // Prioritize the active language if set
            let results = await service.translateToAll(
                text: text,
                from: sourceLanguage,
                to: downloadedTargetLanguages,
                priorityLanguage: activePriorityLanguage,
                includeRomanization: includeRomanization,
                onEachResult: { @MainActor result in
                    // Add or update translation as it arrives
                    if let index = translations.firstIndex(where: { $0.language == result.language }) {
                        translations[index] = result
                    } else {
                        translations.append(result)
                    }

                    // Remove from loading set
                    loadingLanguages.remove(result.language)

                    // Extract source romanization from first result if available
                    if includeRomanization && sourceRomanization == nil {
                        sourceRomanization = result.sourceRomanization
                    }
                }
            )

            // Fallback: extract source romanization if not yet set
            if includeRomanization, sourceRomanization == nil, let firstResult = results.first {
                sourceRomanization = firstResult.sourceRomanization
            }

            // Clear loading state
            isTranslating = false
            loadingLanguages = []

            // Auto-save to history with AI-powered tagging
            if autoSaveToHistory && !results.isEmpty {
                await historyService.saveTranslations(
                    results,
                    sourceText: text,
                    context: modelContext,
                    aiService: aiService,
                    tagService: tagService
                )
            }
        } catch {
            isTranslating = false
            loadingLanguages = []
            errorMessage = ErrorMessage.from(error)
            errorTrigger = UUID()
        }
    }

    private func retryLastTranslation() {
        guard !inputText.isEmpty else { return }
        Task {
            await performTranslation(text: inputText)
        }
    }

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                // Set image first
                await MainActor.run {
                    selectedImage = image
                }
                // Small delay to ensure state propagation, then show sheet
                // This ensures the view has updated with the new image before sheet is presented
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                await MainActor.run {
                    // Verify image is still set before showing sheet
                    if selectedImage != nil {
                        showImageTranslation = true
                    }
                }
            } else {
                // Failed to load image data
                await MainActor.run {
                    selectedImage = nil
                    showImageTranslation = false
                }
            }
        } catch {
            print("Failed to load image: \(error)")
            await MainActor.run {
                selectedImage = nil
                showImageTranslation = false
            }
        }
    }
    
    private func loadInstalledLanguages() async {
        var installed: Set<Locale.Language> = []

        // Use a reference language to check installation status
        // We'll use English as the reference since it's commonly installed
        let referenceLanguage = Locale.Language(identifier: "en")

        // Check each language in our curated list to see if it's actually installed
        for languageInfo in SupportedLanguages.all {
            let language = languageInfo.language

            // Check if this language is installed by checking translation pair availability
            let status = await service.getLanguageStatus(from: referenceLanguage, to: language)

            if status == .installed {
                installed.insert(language)
            }

            // Also check the reverse direction and add reference language itself
            if language.minimalIdentifier == referenceLanguage.minimalIdentifier {
                installed.insert(language)
            }
        }

        installedLanguages = installed
    }
}

// MARK: - Source Language Picker View

struct SourceLanguagePickerView: View {
    let detectedLanguages: [(language: Locale.Language, confidence: Double, isDownloaded: Bool)]
    let installedLanguages: Set<Locale.Language>
    @Binding var selectedSourceLanguage: Locale.Language?
    let onAutoDetect: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var downloadedLanguages: [LanguageInfo] {
        SupportedLanguages.all.filter { languageInfo in
            installedLanguages.contains(languageInfo.language)
        }.sorted { $0.name < $1.name }
    }
    
    private var notDownloadedLanguages: [LanguageInfo] {
        SupportedLanguages.all.filter { languageInfo in
            !installedLanguages.contains(languageInfo.language)
        }.sorted { $0.name < $1.name }
    }
    
    private var filteredDownloadedLanguages: [LanguageInfo] {
        if searchText.isEmpty {
            return downloadedLanguages
        }
        return downloadedLanguages.filter { languageInfo in
            languageInfo.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private var filteredNotDownloadedLanguages: [LanguageInfo] {
        if searchText.isEmpty {
            return notDownloadedLanguages
        }
        return notDownloadedLanguages.filter { languageInfo in
            languageInfo.name.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Download more languages button
                Section {
                    Button {
                        openTranslateSettings()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.blue)
                            Text("Download More Languages")
                                .foregroundStyle(.blue)
                            Spacer()
                            Image(systemName: "arrow.forward")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Auto-detect option
                Section {
                    Button {
                        onAutoDetect()
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto-detect")
                                    .foregroundStyle(.primary)
                                if !detectedLanguages.isEmpty {
                                    let downloadedDetected = detectedLanguages.filter { $0.isDownloaded }
                                    if !downloadedDetected.isEmpty {
                                        Text("Currently: \(downloadedDetected.map { Locale.current.localizedString(forLanguageCode: $0.language.minimalIdentifier) ?? $0.language.minimalIdentifier }.prefix(3).joined(separator: ", "))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            if selectedSourceLanguage == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("Detection Mode")
                }
                
                // Detected languages section
                if !detectedLanguages.isEmpty {
                    Section {
                        ForEach(detectedLanguages, id: \.language.minimalIdentifier) { detected in
                            Button {
                                if detected.isDownloaded {
                                    selectedSourceLanguage = detected.language
                                    dismiss()
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(Locale.current.localizedString(forLanguageCode: detected.language.minimalIdentifier) ?? detected.language.minimalIdentifier)
                                            .foregroundStyle(detected.isDownloaded ? .primary : .secondary)
                                        
                                        HStack(spacing: 4) {
                                            ConfidenceBadge(confidence: detected.confidence)
                                            
                                            if !detected.isDownloaded {
                                                Text("Download Required")
                                                    .font(.caption2)
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.orange)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if detected.isDownloaded && selectedSourceLanguage?.minimalIdentifier == detected.language.minimalIdentifier {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(!detected.isDownloaded)
                            .opacity(detected.isDownloaded ? 1.0 : 0.6)
                        }
                    } header: {
                        Text("Detected Languages")
                    }
                }
                
                // Downloaded languages
                if !filteredDownloadedLanguages.isEmpty {
                    Section {
                        ForEach(filteredDownloadedLanguages) { languageInfo in
                            Button {
                                selectedSourceLanguage = languageInfo.language
                                dismiss()
                            } label: {
                                HStack {
                                    Text(languageInfo.name)
                                        .foregroundStyle(.primary)
                                    
                                    Spacer()
                                    
                                    if selectedSourceLanguage?.minimalIdentifier == languageInfo.language.minimalIdentifier {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Downloaded Languages")
                    }
                }
                
                // Not downloaded languages (text only)
                if !filteredNotDownloadedLanguages.isEmpty {
                    Section {
                        ForEach(filteredNotDownloadedLanguages) { languageInfo in
                            HStack {
                                Text(languageInfo.name)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Download required")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Available After Download")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search languages")
            .navigationTitle("Source Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func openTranslateSettings() {
        // Try to open iOS Translate settings
        if let url = URL(string: "App-prefs:TRANSLATE") {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to general Settings if Translate-specific URL doesn't work
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
        }
    }
}

// MARK: - Source Language Chip Row

struct SourceLanguageChipRow: View {
    let availableLanguages: [Locale.Language]
    let selectedLanguage: Locale.Language?
    let onLanguageSelected: (Locale.Language) -> Void
    let onAutoSelected: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Auto option
                Button {
                    onAutoSelected()
                } label: {
                    Text("Auto")
                        .font(.subheadline)
                        .fontWeight(selectedLanguage == nil ? .semibold : .regular)
                        .foregroundStyle(selectedLanguage == nil ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedLanguage == nil ? Color.accentColor : Color(.secondarySystemFill))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Language options
                ForEach(availableLanguages, id: \.minimalIdentifier) { language in
                    let isActive = selectedLanguage?.minimalIdentifier == language.minimalIdentifier
                    let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier

                    Button {
                        onLanguageSelected(language)
                    } label: {
                        Text(languageName)
                            .font(.subheadline)
                            .fontWeight(isActive ? .semibold : .regular)
                            .foregroundStyle(isActive ? .white : .primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(isActive ? Color.accentColor : Color(.secondarySystemFill))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Confidence Badge

struct ConfidenceBadge: View {
    let confidence: Double
    
    private var color: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.5 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var label: String {
        String(format: "%.0f%%", confidence * 100)
    }
    
    var body: some View {
        Text(label)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}

#Preview {
    TranslationView(initialText: .constant(""))
}
