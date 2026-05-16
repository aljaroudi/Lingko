//
//  TranslationView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData
#if os(iOS)
import PhotosUI
#elseif os(macOS)
import UniformTypeIdentifiers
#endif
import Translation

struct TranslationView: View {
    private struct PendingAutosaveSnapshot {
        let requestID: UUID
        let sourceText: String
        let results: [TranslationResult]
        let fingerprint: String
    }

    @Environment(\.modelContext) private var modelContext

    @State private var service = TranslationService()
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
#if os(iOS)
    @State private var selectedPhotoItem: PhotosPickerItem?
#elseif os(macOS)
    @State private var showImagePicker = false
#endif
    @State private var selectedImage: PlatformImage?

    // Computed binding that only shows sheet when image is available
    private var showImageTranslationBinding: Binding<Bool> {
        Binding(
            get: { showImageTranslation && selectedImage != nil },
            set: { newValue in
                showImageTranslation = newValue
                if !newValue {
                    // Clear image when sheet is dismissed
                    selectedImage = nil
#if os(iOS)
                    selectedPhotoItem = nil
#endif
                }
            }
        )
    }
    @State private var debounceTask: Task<Void, Never>?
    @State private var detectedLanguages: [(language: Locale.Language, confidence: Double, isDownloaded: Bool)] = []
    @State private var selectedSourceLanguage: Locale.Language? = nil
    @State private var currentSourceLanguage: Locale.Language? = nil
    @State private var installedLanguages: Set<Locale.Language> = []
    @State private var sourceRomanization: String?
    @State private var errorMessage: ErrorMessage?
    @State private var errorTrigger = UUID()
    @State private var showDownloadSheet = false
    @State private var pendingAutosaveSnapshot: PendingAutosaveSnapshot?
    @State private var pendingAutosaveIsDirty = false
    @State private var lastCommittedAutosaveFingerprint: String?
    @State private var isCommittingAutosave = false
    @State private var latestTranslationRequestID = UUID()
    @FocusState private var isInputFocused: Bool

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
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .errorBanner($errorMessage, onRetry: retryLastTranslation)
                .toolbar {
#if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            dismissInputFocus()
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
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                dismissInputFocus()
                            }
                        )
                    }
#elseif os(macOS)
                    ToolbarItem(placement: .automatic) {
                        Button {
                            dismissInputFocus()
                            showSettings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                        .accessibilityLabel("Settings")
                        .accessibilityHint("Open app settings")
                    }

                    ToolbarItemGroup(placement: .automatic) {
                        Button {
                            dismissInputFocus()
                            showImagePicker = true
                        } label: {
                            Label("Import Image", systemImage: "photo")
                        }
                    }
#endif
                }
                .sheet(isPresented: $showSettings, onDismiss: { Task { await loadInstalledLanguages() } }) {
                    SettingsView()
                }
                .sheet(isPresented: showImageTranslationBinding) {
                    // The binding guarantees selectedImage is non-nil when sheet is shown
                    if let image = selectedImage {
                        CameraTranslationView(
                            initialImage: image,
                            selectedLanguages: installedLanguages,
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
#if os(macOS)
                .fileImporter(
                    isPresented: $showImagePicker,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: false
                ) { result in
                    Task {
                        await handleFileImport(result)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .importImage)) { _ in
                    showImagePicker = true
                }
                .onDrop(of: [.plainText, .image], isTargeted: nil) { providers in
                    handleDrop(providers: providers)
                    return true
                }
#endif
                .onChange(of: selectedSourceLanguage) { _, newLanguage in
                    // Update current source language when manually selected
                    if let newLanguage = newLanguage {
                        currentSourceLanguage = newLanguage

                        // If active priority language is same as new source, switch to another
                        if activePriorityLanguage == newLanguage {
                            let availableTargets = installedLanguages.filter { $0 != newLanguage }
                            activePriorityLanguage = availableTargets.sorted(by: { l1, l2 in
                                (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                                    (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                            }).first
                        }

                        if !inputText.isEmpty {
                            handleTextChange(inputText)
                        }
                    } else if !inputText.isEmpty {
                        // If auto-detect is selected, trigger translation to recalculate
                        handleTextChange(inputText)
                    }
                }
#if os(iOS)
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
#endif
                .onChange(of: isInputFocused) { oldValue, newValue in
                    guard oldValue, !newValue else { return }

                    Task {
                        await commitPendingAutosaveIfNeeded()
                    }
                }
                .onDisappear {
                    dismissInputFocus()

                    Task {
                        await commitPendingAutosaveIfNeeded()
                    }
                }
                .task {
                    await loadInstalledLanguages()

                    // Initialize active priority language on first load
                    if activePriorityLanguage == nil && !installedLanguages.isEmpty {
                        activePriorityLanguage = installedLanguages.sorted(by: { l1, l2 in
                            (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                                (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                        }).first
                    }
                }
#if os(iOS)
                .sensoryFeedback(.impact(weight: .light), trigger: translations.count)
                .sensoryFeedback(.error, trigger: errorTrigger)
#endif
        }
        .sheet(
            isPresented: $showDownloadSheet,
            onDismiss: { Task { await loadInstalledLanguages() } }
        ) {
            LanguageDownloadView()
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            inputSection
            Spacer(minLength: 0)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture().onEnded { dismissInputFocus() }
                )
        }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {
        VStack(spacing: 0) {
            // Source panel
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Menu {
                        Button("Auto") {
                            dismissInputFocus()
                            selectedSourceLanguage = nil
                            if !inputText.isEmpty { handleTextChange(inputText) }
                        }
                        ForEach(
                            sortedInstalledLanguages.filter { $0.minimalIdentifier != activePriorityLanguage?.minimalIdentifier },
                            id: \.minimalIdentifier
                        ) { lang in
                            Button(localizedLanguageName(for: lang)) {
                                dismissInputFocus()
                                selectedSourceLanguage = lang
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(sourceLanguageLabel)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "mic")
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Voice input (coming soon)")
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $inputText)
                        .frame(minHeight: 80, maxHeight: 200)
                        .background(Color.platformBackground)
                        .focused($isInputFocused)
                        .onChange(of: inputText) { _, newValue in
                            handleTextChange(newValue)
                        }
                    if inputText.isEmpty {
                        Text("Enter text")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }

                if let romanization = sourceRomanization {
                    Text(romanization)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .textSelection(.enabled)
                }
            }
            .padding()

            // Swap divider
            ZStack {
                Divider()
                Button(action: swapLanguages) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.caption)
                        .padding(8)
                        .background(Color(.secondarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Swap languages")
            }

            // Target panel
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Menu {
                        let sourceLangID = selectedSourceLanguage?.minimalIdentifier ?? currentSourceLanguage?.minimalIdentifier ?? ""
                        ForEach(
                            sortedInstalledLanguages.filter { $0.minimalIdentifier != sourceLangID },
                            id: \.minimalIdentifier
                        ) { lang in
                            Button(localizedLanguageName(for: lang)) {
                                dismissInputFocus()
                                activePriorityLanguage = lang
                                if !inputText.isEmpty { handleTextChange(inputText) }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(targetLanguageLabel)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.accent)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                                .foregroundStyle(.accent)
                        }
                    }
                    Spacer()
                    Image(systemName: "mic")
                        .foregroundStyle(.accent)
                        .accessibilityLabel("Voice input (coming soon)")
                }

                Group {
                    if let translation = activeTranslation {
                        Text(translation.translation)
                            .font(.title3)
                            .foregroundStyle(.accent)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: translation.layoutDirection == .rightToLeft ? .trailing : .leading)
                            .environment(\.layoutDirection, translation.layoutDirection)
                            .transition(.opacity)
                    } else if let lang = activePriorityLanguage, loadingLanguages.contains(lang) {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(minHeight: 60, alignment: .topLeading)
            }
            .padding()
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded { dismissInputFocus() }
            )
        }
    }

    // MARK: - Input Helpers

    private var sortedInstalledLanguages: [Locale.Language] {
        installedLanguages.sorted { localizedLanguageName(for: $0) < localizedLanguageName(for: $1) }
    }

    private var activeTranslation: TranslationResult? {
        guard let lang = activePriorityLanguage else { return nil }
        return translations.first { $0.language == lang }
    }

    private var sourceLanguageLabel: String {
        if let lang = selectedSourceLanguage { return localizedLanguageName(for: lang) }
        if let detected = currentSourceLanguage { return localizedLanguageName(for: detected) }
        return String(localized: "Auto")
    }

    private var targetLanguageLabel: String {
        if let lang = activePriorityLanguage { return localizedLanguageName(for: lang) }
        return sortedInstalledLanguages.first.map { localizedLanguageName(for: $0) } ?? String(localized: "Select language")
    }

    private func swapLanguages() {
        let newSource = activePriorityLanguage
        let newTarget = currentSourceLanguage
        let newInput = activeTranslation?.translation ?? inputText
        selectedSourceLanguage = newSource
        activePriorityLanguage = newTarget
        inputText = newInput
        dismissInputFocus()
        if !inputText.isEmpty { handleTextChange(inputText) }
    }

    // MARK: - Translation Logic

    private func handleTextChange(_ text: String) {
        // Cancel previous debounce task
        debounceTask?.cancel()

        let requestID = UUID()
        latestTranslationRequestID = requestID

        // Clear translations if text is empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translations = []
            detectedLanguages = []
            selectedSourceLanguage = nil
            currentSourceLanguage = nil
            sourceRomanization = nil
            isTranslating = false
            loadingLanguages = []
            clearPendingAutosave(resetLastCommitted: true)
            return
        }

        // Create new debounced task for translation
        debounceTask = Task {
            do {
                try await Task.sleep(for: debounceDelay)

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                await performTranslation(text: text, requestID: requestID)
            } catch {
                // Task was cancelled or sleep failed
            }
        }
    }

    private func performTranslation(text: String, requestID: UUID) async {
        guard requestID == latestTranslationRequestID else { return }

        isTranslating = true
        errorMessage = nil
        sourceRomanization = nil

        do {
            // Detect languages with preference for user-selected languages
            let detected = service.detectLanguages(
                for: text,
                preferredLanguages: installedLanguages,
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
                    installedLanguages.contains(result.language)
                }

                if let best = detectedAndSelected {
                    sourceLanguage = best.language
                } else {
                    // Fallback to any detected language
                    sourceLanguage = detected.first?.language
                }
            }

            // Check if we have a valid source language
            guard let sourceLanguage = sourceLanguage else {
                throw TranslationError.detectionFailed
            }

            // Update current source language for UI display
            currentSourceLanguage = sourceLanguage

            // If active priority language is same as source, switch to another available target
            if activePriorityLanguage == sourceLanguage {
                let availableTargets = installedLanguages.filter { $0 != sourceLanguage }
                activePriorityLanguage = availableTargets.sorted(by: { l1, l2 in
                    (Locale.current.localizedString(forLanguageCode: l1.minimalIdentifier) ?? l1.minimalIdentifier) <
                        (Locale.current.localizedString(forLanguageCode: l2.minimalIdentifier) ?? l2.minimalIdentifier)
                }).first
            }

            // Translate only to the selected target language
            guard let targetLanguage = activePriorityLanguage else {
                throw TranslationError.invalidConfiguration
            }

            guard installedLanguages.contains(targetLanguage) else {
                let missingName = Locale.current.localizedString(forLanguageCode: targetLanguage.minimalIdentifier)
                throw TranslationError.missingLanguagePacks([missingName].compactMap { $0 })
            }

            let downloadedTargetLanguages: Set<Locale.Language> = [targetLanguage]

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
                    guard requestID == latestTranslationRequestID else { return }

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

            guard requestID == latestTranslationRequestID else { return }

            // Fallback: extract source romanization if not yet set
            if includeRomanization, sourceRomanization == nil, let firstResult = results.first {
                sourceRomanization = firstResult.sourceRomanization
            }

            // Clear loading state
            isTranslating = false
            loadingLanguages = []

            updatePendingAutosaveSnapshot(
                requestID: requestID,
                sourceText: text,
                results: results
            )

            if !isInputFocused {
                await commitPendingAutosaveIfNeeded()
            }
        } catch {
            guard requestID == latestTranslationRequestID else { return }

            isTranslating = false
            loadingLanguages = []
            if let translationError = error as? TranslationError,
               case .missingLanguagePacks = translationError {
                errorMessage = ErrorMessage(
                    title: translationError.errorDescription ?? "Language packs missing",
                    message: translationError.recoverySuggestion,
                    severity: .warning,
                    actionTitle: "Download",
                    action: { showDownloadSheet = true }
                )
            } else {
                errorMessage = ErrorMessage.from(error)
            }
            errorTrigger = UUID()
        }
    }

    private func retryLastTranslation() {
        guard !inputText.isEmpty else { return }

        debounceTask?.cancel()
        let requestID = UUID()
        latestTranslationRequestID = requestID

        Task {
            await performTranslation(text: inputText, requestID: requestID)
        }
    }

    private func dismissInputFocus() {
        isInputFocused = false
    }

    private func updatePendingAutosaveSnapshot(
        requestID: UUID,
        sourceText: String,
        results: [TranslationResult]
    ) {
        guard !results.isEmpty else {
            clearPendingAutosave()
            return
        }

        let fingerprint = makeAutosaveFingerprint(sourceText: sourceText, results: results)
        pendingAutosaveSnapshot = PendingAutosaveSnapshot(
            requestID: requestID,
            sourceText: sourceText,
            results: results,
            fingerprint: fingerprint
        )
        pendingAutosaveIsDirty = fingerprint != lastCommittedAutosaveFingerprint
    }

    private func clearPendingAutosave(resetLastCommitted: Bool = false) {
        pendingAutosaveSnapshot = nil
        pendingAutosaveIsDirty = false

        if resetLastCommitted {
            lastCommittedAutosaveFingerprint = nil
        }
    }

    private func makeAutosaveFingerprint(sourceText: String, results: [TranslationResult]) -> String {
        let sourceLanguageCode = results.first?.sourceLanguage?.minimalIdentifier ?? ""
        let translatedEntries = results
            .sorted { $0.language.minimalIdentifier < $1.language.minimalIdentifier }
            .map { "\($0.language.minimalIdentifier)\u{1F}\($0.translation)" }
            .joined(separator: "\u{1E}")

        return [sourceText, sourceLanguageCode, translatedEntries].joined(separator: "\u{1D}")
    }

    private func eligiblePendingAutosaveSnapshot() -> PendingAutosaveSnapshot? {
        guard autoSaveToHistory,
              pendingAutosaveIsDirty,
              let snapshot = pendingAutosaveSnapshot,
              !snapshot.results.isEmpty,
              snapshot.fingerprint != lastCommittedAutosaveFingerprint,
              snapshot.requestID == latestTranslationRequestID,
              snapshot.sourceText == inputText else {
            return nil
        }

        return snapshot
    }

    private func commitPendingAutosaveIfNeeded() async {
        guard !isCommittingAutosave else { return }

        isCommittingAutosave = true
        defer { isCommittingAutosave = false }

        while let snapshot = eligiblePendingAutosaveSnapshot() {
            await historyService.saveTranslations(
                snapshot.results,
                sourceText: snapshot.sourceText,
                context: modelContext,
                aiService: aiService,
                tagService: tagService
            )

            lastCommittedAutosaveFingerprint = snapshot.fingerprint

            if pendingAutosaveSnapshot?.fingerprint == snapshot.fingerprint {
                pendingAutosaveIsDirty = false
            }
        }
    }

#if os(iOS)
    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item = item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = PlatformImage(data: data) {
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
#endif

#if os(macOS)
    private func handleFileImport(_ result: Result<[URL], Error>) async {
        do {
            let urls = try result.get()
            guard let url = urls.first else { return }

            let data = try Data(contentsOf: url)
            guard let image = PlatformImage(data: data) else {
                await MainActor.run {
                    selectedImage = nil
                    showImageTranslation = false
                }
                return
            }

            await MainActor.run {
                selectedImage = image
            }

            try? await Task.sleep(nanoseconds: 10_000_000)
            await MainActor.run {
                if selectedImage != nil {
                    showImageTranslation = true
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

    private func handleDrop(providers: [NSItemProvider]) {
        // Handle text drop
        if let textProvider = providers.first(where: { $0.hasItemConformingToTypeIdentifier("public.plain-text") }) {
            textProvider.loadItem(forTypeIdentifier: "public.plain-text", options: nil) { item, error in
                if let data = item as? Data, let text = String(data: data, encoding: .utf8) {
                    Task { @MainActor in
                        inputText = text
                    }
                } else if let text = item as? String {
                    Task { @MainActor in
                        inputText = text
                    }
                }
            }
            return
        }

        // Handle image drop
        if let imageProvider = providers.first(where: { $0.canLoadObject(ofClass: PlatformImage.self) }) {
            imageProvider.loadObject(ofClass: PlatformImage.self) { item, error in
                if let image = item as? PlatformImage {
                    Task { @MainActor in
                        selectedImage = image
                        try? await Task.sleep(nanoseconds: 10_000_000)
                        if selectedImage != nil {
                            showImageTranslation = true
                        }
                    }
                }
            }
        }
    }
#endif

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

private func localizedLanguageName(for language: Locale.Language) -> String {
    Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
}

private func sortedLanguages(_ languages: [Locale.Language]) -> [Locale.Language] {
    languages.sorted { localizedLanguageName(for: $0) < localizedLanguageName(for: $1) }
}

#Preview {
    TranslationView(initialText: .constant(""))
}
