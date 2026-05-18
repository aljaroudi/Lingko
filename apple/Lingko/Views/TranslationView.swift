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
import UIKit
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
    @State private var inputDismissedForCurrentRequest = true
    @FocusState private var isInputFocused: Bool

    @State private var audioService = AudioService()
    @State private var speechService = SpeechService()
    @State private var currentSavedTranslation: SavedTranslation?
    @State private var isSpeakingSource = false
    @State private var isSpeakingTranslation = false
    @State private var showCopyConfirmation = false
    @AppStorage("defaultSpeechRate") private var defaultSpeechRate: Double = 0.5

    // Language persistence
    @AppStorage("preferredTargetLanguageCode") private var preferredTargetLanguageCode: String = ""
    @AppStorage("preferredSourceLanguageCode") private var preferredSourceLanguageCode: String = ""
    @AppStorage("disabledLanguageCodes") private var disabledLanguageCodes: String = ""

    // Feature toggles
    @AppStorage("includeRomanization") private var includeRomanization: Bool = true
    @AppStorage("autoSaveToHistory") private var autoSaveToHistory: Bool = true

    private let debounceDelay: Duration = .milliseconds(300)

    private var sourceInputLanguage: Locale.Language? {
        selectedSourceLanguage ?? currentSourceLanguage
    }

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
                    if speechService.isRecording { speechService.stopRecording() }
                    inputDismissedForCurrentRequest = true
                    Task {
                        await commitPendingAutosaveIfNeeded()
                    }
                }
                .onChange(of: speechService.transcript) { _, newValue in
                    guard speechService.isRecording else { return }
                    inputText = newValue
                }
                .onDisappear {
                    dismissInputFocus()

                    Task {
                        await commitPendingAutosaveIfNeeded()
                    }
                }
                .task {
                    await loadInstalledLanguages()

                    // Restore saved target language if still installed
                    if !preferredTargetLanguageCode.isEmpty {
                        let saved = Locale.Language(identifier: preferredTargetLanguageCode)
                        if installedLanguages.contains(saved) {
                            activePriorityLanguage = saved
                        }
                    }
                    // Restore saved source language override (empty = auto)
                    if !preferredSourceLanguageCode.isEmpty {
                        selectedSourceLanguage = Locale.Language(identifier: preferredSourceLanguageCode)
                    }

                    // Fall back to first alphabetical installed language if nothing set
                    if activePriorityLanguage == nil && !installedLanguages.isEmpty {
                        activePriorityLanguage = firstAvailableTarget(excluding: selectedSourceLanguage)
                    }
                }
                .onChange(of: disabledLanguageCodes) {
                    Task {
                        await loadInstalledLanguages()
                        if !inputText.isEmpty {
                            handleTextChange(inputText)
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .supportedLanguagesDidChange)) { _ in
                    Task {
                        await loadInstalledLanguages()
                        if !inputText.isEmpty {
                            handleTextChange(inputText)
                        }
                    }
                }
                .onChange(of: activePriorityLanguage) { _, newLang in
                    preferredTargetLanguageCode = newLang?.minimalIdentifier ?? ""
                }
                .onChange(of: selectedSourceLanguage) { _, newLang in
                    preferredSourceLanguageCode = newLang?.minimalIdentifier ?? ""
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
            NavigationStack {
                LanguageDownloadView()
            }
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
                    sourceTrailingButton
                }

                ZStack(alignment: .topLeading) {
#if os(iOS)
                    LanguageAwareTextEditor(
                        text: $inputText,
                        inputLanguage: sourceInputLanguage,
                        isFocused: $isInputFocused
                    )
                    .frame(minHeight: 80, maxHeight: 200)
                    .background(Color.platformBackground)
#elseif os(macOS)
                    TextEditor(text: $inputText)
                        .frame(minHeight: 80, maxHeight: 200)
                        .background(Color.platformBackground)
                        .focused($isInputFocused)
#endif
                    if inputText.isEmpty {
                        Text("Enter text")
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                }
                .onChange(of: inputText) { _, newValue in
                    inputDismissedForCurrentRequest = !isInputFocused
                    handleTextChange(newValue)
                }

                if let romanization = sourceRomanization {
                    Text(romanization)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                if !isInputFocused, let translation = activeTranslation {
                    translationCard(for: translation)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding()
            .animation(.easeInOut(duration: 0.2), value: isInputFocused)
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

    private func firstAvailableTarget(excluding sourceLanguage: Locale.Language?) -> Locale.Language? {
        sortedInstalledLanguages.first { language in
            language.minimalIdentifier != sourceLanguage?.minimalIdentifier
        }
    }

    private func reconcileLanguageSelection() {
        if let selectedSourceLanguage, !installedLanguages.contains(selectedSourceLanguage) {
            self.selectedSourceLanguage = nil
        }

        if let currentSourceLanguage, !installedLanguages.contains(currentSourceLanguage) {
            self.currentSourceLanguage = nil
        }

        let sourceLanguage = selectedSourceLanguage ?? currentSourceLanguage
        if let activePriorityLanguage, !installedLanguages.contains(activePriorityLanguage) {
            self.activePriorityLanguage = firstAvailableTarget(excluding: sourceLanguage)
        } else if activePriorityLanguage == nil {
            activePriorityLanguage = firstAvailableTarget(excluding: sourceLanguage)
        }
    }

    // MARK: - Source Trailing Button

    @ViewBuilder
    private var sourceTrailingButton: some View {
        if isInputFocused {
            Button(action: toggleRecording) {
                Image(systemName: speechService.isRecording ? "mic.fill" : "mic")
                    .foregroundStyle(speechService.isRecording ? Color.red : Color.secondary)
                    .symbolEffect(.pulse, isActive: speechService.isRecording)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(speechService.isRecording ? "Stop recording" : "Start voice input")
        } else if !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Button(action: toggleSourceSpeech) {
                Image(systemName: isSpeakingSource ? "stop.circle.fill" : "speaker.wave.2")
                    .foregroundStyle(Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSpeakingSource ? "Stop speaking" : "Speak source text")
        }
    }

    // MARK: - Translation Card

    @ViewBuilder
    private func translationCard(for translation: TranslationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let romanization = translation.romanization {
                Text(romanization)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
                    .textSelection(.enabled)
            }
            HStack(spacing: 20) {
                Button(action: { toggleTranslationSpeech(translation) }) {
                    Image(systemName: isSpeakingTranslation ? "stop.circle.fill" : "speaker.wave.2")
                        .foregroundStyle(.accent)
                }
                .accessibilityLabel(isSpeakingTranslation ? "Stop speaking" : "Speak translation")

                Button(action: toggleFavorite) {
                    Image(systemName: (currentSavedTranslation?.isFavorite ?? false) ? "star.fill" : "star")
                        .foregroundStyle((currentSavedTranslation?.isFavorite ?? false) ? Color.yellow : Color.accentColor)
                }
                .accessibilityLabel((currentSavedTranslation?.isFavorite ?? false) ? "Remove from favorites" : "Add to favorites")

                Button(action: { copyTranslation(translation) }) {
                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(.accent)
                }
                .accessibilityLabel(showCopyConfirmation ? "Copied" : "Copy translation")

                Spacer(minLength: 0)
            }
            .buttonStyle(.plain)
            .font(.title3)
        }
        .padding(.top, 4)
    }

    // MARK: - STT Actions

    private func toggleRecording() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                let ok = await speechService.requestPermissions()
                guard ok else {
                    errorMessage = ErrorMessage(
                        title: "Permission needed",
                        message: speechService.lastError ?? "Microphone or speech recognition permission denied. Enable in Settings.",
                        severity: .warning
                    )
                    errorTrigger = UUID()
                    return
                }
                do {
                    try speechService.startRecording(locale: sttLocale())
                } catch {
                    errorMessage = ErrorMessage.from(error)
                    errorTrigger = UUID()
                }
            }
        }
    }

    private func sttLocale() -> Locale {
        let lang = selectedSourceLanguage ?? currentSourceLanguage
        if let lang { return Locale(identifier: lang.minimalIdentifier) }
        return .current
    }

    // MARK: - TTS Actions

    private func toggleSourceSpeech() {
        if isSpeakingSource {
            audioService.stop()
            isSpeakingSource = false
            return
        }
        let lang = currentSourceLanguage ?? selectedSourceLanguage ?? Locale.Language(identifier: Locale.current.identifier)
        audioService.speak(text: inputText, language: lang, rate: Float(defaultSpeechRate))
        isSpeakingSource = true
        monitorSpeech(isActive: { isSpeakingSource }, clear: { isSpeakingSource = false })
    }

    private func toggleTranslationSpeech(_ translation: TranslationResult) {
        if isSpeakingTranslation {
            audioService.stop()
            isSpeakingTranslation = false
            return
        }
        audioService.speak(text: translation.translation, language: translation.language, rate: Float(defaultSpeechRate))
        isSpeakingTranslation = true
        monitorSpeech(isActive: { isSpeakingTranslation }, clear: { isSpeakingTranslation = false })
    }

    private func monitorSpeech(isActive: @escaping () -> Bool, clear: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            while isActive() && audioService.isPlaying {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if isActive() && !audioService.isPlaying { clear() }
        }
    }

    // MARK: - Card Actions

    private func copyTranslation(_ translation: TranslationResult) {
        PlatformUtils.copyToPasteboard(translation.translation)
        withAnimation { showCopyConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyConfirmation = false }
        }
    }

    private func toggleFavorite() {
        Task {
            if let existing = currentSavedTranslation {
                historyService.toggleFavorite(existing, context: modelContext)
                return
            }
            guard let snapshot = pendingAutosaveSnapshot ?? makeFallbackSnapshot() else { return }
            if let saved = await historyService.saveTranslations(
                snapshot.results,
                sourceText: snapshot.sourceText,
                context: modelContext,
                aiService: aiService,
                tagService: tagService
            ) {
                currentSavedTranslation = saved
                if !saved.isFavorite {
                    historyService.toggleFavorite(saved, context: modelContext)
                }
                lastCommittedAutosaveFingerprint = snapshot.fingerprint
                pendingAutosaveIsDirty = false
            }
        }
    }

    private func makeFallbackSnapshot() -> PendingAutosaveSnapshot? {
        guard !translations.isEmpty, !inputText.isEmpty else { return nil }
        return PendingAutosaveSnapshot(
            requestID: latestTranslationRequestID,
            sourceText: inputText,
            results: translations,
            fingerprint: makeAutosaveFingerprint(sourceText: inputText, results: translations)
        )
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
            currentSourceLanguage = selectedSourceLanguage
            sourceRomanization = nil
            loadingLanguages = []
            currentSavedTranslation = nil
            clearPendingAutosave(resetLastCommitted: true)
            inputDismissedForCurrentRequest = true
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

        errorMessage = nil
        sourceRomanization = nil

        do {
            // Determine source language with priority:
            // 1. Manual override (if set)
            // 2. Highest confidence language that's user-selected (doesn't need to be downloaded)
            // 3. Highest confidence detected language
            // Note: Source language doesn't need to be downloaded, only target languages do
            let sourceLanguage: Locale.Language
            if let manual = selectedSourceLanguage {
                sourceLanguage = manual
            } else {
                // Detect languages with preference for user-selected languages
                let detected = service.detectLanguages(
                    for: text,
                    preferredLanguages: installedLanguages,
                    installedLanguages: installedLanguages,
                    maxResults: 5
                )

                // Find best language that's also user-selected
                let detectedAndSelected = detected.first { result in
                    installedLanguages.contains(result.language)
                }

                if let best = detectedAndSelected {
                    sourceLanguage = best.language
                } else if let best = detected.first {
                    // Fallback to any detected language
                    sourceLanguage = best.language
                } else {
                    throw TranslationError.detectionFailed
                }
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

            // Set loading state for the selected target language (excluding source)
            loadingLanguages = targetLanguage == sourceLanguage ? [] : [targetLanguage]

            // Clear old translations to prepare for new ones
            translations = []

            // Perform translation only to the selected target language
            let result = await service.translate(
                text: text,
                from: sourceLanguage,
                to: targetLanguage,
                includeRomanization: includeRomanization
            )

            guard requestID == latestTranslationRequestID else { return }

            let results = result.map { [$0] } ?? []
            translations = results

            if includeRomanization, let result {
                sourceRomanization = result.sourceRomanization
            }

            // Clear loading state
            loadingLanguages = []

            updatePendingAutosaveSnapshot(
                requestID: requestID,
                sourceText: text,
                results: results
            )

            if inputDismissedForCurrentRequest {
                await commitPendingAutosaveIfNeeded()
            }
        } catch {
            guard requestID == latestTranslationRequestID else { return }

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
        inputDismissedForCurrentRequest = true
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
              snapshot.sourceText == inputText,
              inputDismissedForCurrentRequest else {
            return nil
        }

        return snapshot
    }

    private func commitPendingAutosaveIfNeeded() async {
        guard !isCommittingAutosave else { return }

        isCommittingAutosave = true
        defer { isCommittingAutosave = false }

        while let snapshot = eligiblePendingAutosaveSnapshot() {
            let saved = await historyService.saveTranslations(
                snapshot.results,
                sourceText: snapshot.sourceText,
                context: modelContext,
                aiService: aiService,
                tagService: tagService
            )

            if let saved { currentSavedTranslation = saved }
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
        let loadedLanguages = await service.installedLanguages()
        installedLanguages = SupportedLanguages.enabledLanguages(
            from: loadedLanguages,
            disabledLanguageCodes: disabledLanguageCodes
        )
        reconcileLanguageSelection()
    }
}

#if os(iOS)
private struct LanguageAwareTextEditor: UIViewRepresentable {
    @Binding var text: String
    let inputLanguage: Locale.Language?
    let isFocused: FocusState<Bool>.Binding

    func makeUIView(context: Context) -> KeyboardLanguageTextView {
        let textView = KeyboardLanguageTextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }

    func updateUIView(_ textView: KeyboardLanguageTextView, context: Context) {
        context.coordinator.parent = self

        if textView.text != text {
            textView.text = text
        }

        textView.preferredLanguageIdentifier = inputLanguage?.minimalIdentifier

        if isFocused.wrappedValue, !textView.isFirstResponder {
            textView.becomeFirstResponder()
        } else if !isFocused.wrappedValue, textView.isFirstResponder {
            textView.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: LanguageAwareTextEditor

        init(parent: LanguageAwareTextEditor) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            guard parent.text != textView.text else { return }
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused.wrappedValue = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused.wrappedValue = false
        }
    }
}

private final class KeyboardLanguageTextView: UITextView {
    var preferredLanguageIdentifier: String? {
        didSet {
            guard oldValue != preferredLanguageIdentifier else { return }
            reloadInputViews()
        }
    }

    override var textInputMode: UITextInputMode? {
        guard let preferredLanguageIdentifier,
              let inputMode = Self.inputMode(matching: preferredLanguageIdentifier) else {
            return super.textInputMode
        }

        return inputMode
    }

    private static func inputMode(matching preferredIdentifier: String) -> UITextInputMode? {
        let preferred = normalizedLanguageIdentifier(preferredIdentifier)

        if let exactMatch = UITextInputMode.activeInputModes.first(where: { inputMode in
            guard let primaryLanguage = inputMode.primaryLanguage else { return false }
            return normalizedLanguageIdentifier(primaryLanguage) == preferred
        }) {
            return exactMatch
        }

        let preferredBase = baseLanguageCode(preferred)
        return UITextInputMode.activeInputModes.first { inputMode in
            guard let primaryLanguage = inputMode.primaryLanguage else { return false }
            return baseLanguageCode(normalizedLanguageIdentifier(primaryLanguage)) == preferredBase
        }
    }

    private static func normalizedLanguageIdentifier(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: "-").lowercased()
    }

    private static func baseLanguageCode(_ identifier: String) -> String {
        identifier.split(separator: "-").first.map(String.init) ?? identifier
    }
}
#endif

private func localizedLanguageName(for language: Locale.Language) -> String {
    SupportedLanguages.displayName(for: language)
}

#Preview {
    TranslationView(initialText: .constant(""))
}
