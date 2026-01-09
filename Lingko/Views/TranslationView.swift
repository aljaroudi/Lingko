//
//  TranslationView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData
import PhotosUI

struct TranslationView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var service = TranslationService()
    @State private var audioService = AudioService()
    @State private var aiService = AIAssistantService()
    @State private var historyService = HistoryService()
    @State private var translationMemoryService = TranslationMemoryService()
    @State private var tagService = TagService()
    @State private var connectivityService = ConnectivityService()
    @Binding var inputText: String
    @State private var translations: [TranslationResult] = []
    @State private var selectedLanguages: Set<Locale.Language> = LanguagePreferences.loadSelectedLanguages()
    @State private var isTranslating = false
    @State private var showLanguageSelection = false
    @State private var showImageTranslation = false
    @State private var showSettings = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    
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
    @State private var sourceRomanization: String?
    @State private var errorMessage: ErrorMessage?
    @State private var errorTrigger = UUID()
    @FocusState private var isInputFocused: Bool
    @AppStorage("defaultSpeechRate") private var speechRate: Double = 0.5
    @State private var translationMemorySuggestions: [TranslationMemorySuggestion] = []

    // Feature toggles
    @AppStorage("includeLinguisticAnalysis") private var includeLinguisticAnalysis: Bool = false
    @AppStorage("includeRomanization") private var includeRomanization: Bool = true
    @AppStorage("autoSaveToHistory") private var autoSaveToHistory: Bool = true

    private let debounceDelay: Duration = .milliseconds(500)

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

                    ToolbarItem(placement: .primaryAction) {
                        languageSelectionButton
                    }

                    ToolbarItem(placement: .secondaryAction) {
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
                .sheet(isPresented: $showLanguageSelection) {
                    LanguageSelectionView(selectedLanguages: $selectedLanguages)
                }
                .sheet(isPresented: $showSettings) {
                    SettingsView()
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
                .onChange(of: selectedLanguages) { _, newLanguages in
                    LanguagePreferences.saveSelectedLanguages(newLanguages)
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
                .sensoryFeedback(.impact(weight: .light), trigger: translations.count)
                .sensoryFeedback(.error, trigger: errorTrigger)
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Offline warning
            if !connectivityService.isConnected {
                offlineWarningBanner
            }

            // Input section
            inputSection
                .padding()
                .background(Color(.systemGroupedBackground))

            // Translation memory suggestions
            if !translationMemorySuggestions.isEmpty {
                translationMemorySuggestionsSection
            }

            Divider()

            // Results section
            resultsSection
        }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()

                if let detectedLanguage {
                    Text(detectedLanguage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }
            }

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

            if isTranslating {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Translating...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if isTranslating {
            LoadingStateView(style: .skeleton, count: min(selectedLanguages.count, 5))
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else if selectedLanguages.isEmpty {
            EmptyStateView(
                configuration: .noLanguagesSelected {
                    showLanguageSelection = true
                }
            )
            .transition(.opacity)
        } else if translations.isEmpty && !inputText.isEmpty {
            EmptyStateView(configuration: .translationEmpty)
                .transition(.opacity)
        } else if translations.isEmpty {
            EmptyStateView(configuration: .translationEmpty)
                .transition(.opacity)
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(translations) { result in
                        TranslationResultRow(
                            result: result,
                            audioService: audioService,
                            aiService: aiService,
                            speechRate: Float(speechRate)
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.9).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Offline Warning Banner

    @ViewBuilder
    private var offlineWarningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.orange)
            Text("Offline - Language packs may be unavailable")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.orange.opacity(0.1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Translation Memory Suggestions Section

    @ViewBuilder
    private var translationMemorySuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)

                Text("Similar Translations")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    translationMemorySuggestions = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(translationMemorySuggestions) { suggestion in
                        TranslationMemorySuggestionCard(suggestion: suggestion) {
                            applySuggestion(suggestion)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Language Selection Button

    @ViewBuilder
    private var languageSelectionButton: some View {
        Button {
            showLanguageSelection = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                Text("\(selectedLanguages.count)")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .accessibilityLabel("Select target languages")
        .accessibilityValue("\(selectedLanguages.count) languages selected")
        .accessibilityHint("Opens language selection sheet")
    }

    // MARK: - Translation Logic

    private func handleTextChange(_ text: String) {
        // Cancel previous debounce task
        debounceTask?.cancel()

        // Clear translations if text is empty
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            translations = []
            detectedLanguage = nil
            sourceRomanization = nil
            translationMemorySuggestions = []
            isTranslating = false
            return
        }

        // Fetch translation memory suggestions immediately (no debounce)
        translationMemorySuggestions = translationMemoryService.findSimilarTranslations(
            for: text,
            context: modelContext
        )

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
            // Detect language
            let (language, _) = service.detectLanguage(for: text)
            if let language {
                detectedLanguage = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier)
                    ?? language.minimalIdentifier
            }

            // Check if languages are selected
            guard !selectedLanguages.isEmpty else {
                throw TranslationError.invalidConfiguration
            }

            // Perform translation with feature flags
            let results = await service.translateToAll(
                text: text,
                from: language,
                to: selectedLanguages,
                includeLinguisticAnalysis: includeLinguisticAnalysis,
                includeRomanization: includeRomanization
            )

            // Extract source romanization from first result if available
            if includeRomanization, let firstResult = results.first {
                sourceRomanization = firstResult.sourceRomanization
            } else {
                sourceRomanization = nil
            }

            // Update UI
            translations = results
            isTranslating = false

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

    private func applySuggestion(_ suggestion: TranslationMemorySuggestion) {
        // Apply the suggested text
        inputText = suggestion.sourceText

        // Clear translation memory suggestions after applying
        translationMemorySuggestions = []

        // Trigger translation
        handleTextChange(suggestion.sourceText)
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
}

// MARK: - Translation Memory Suggestion Card

struct TranslationMemorySuggestionCard: View {
    let suggestion: TranslationMemorySuggestion
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: suggestion.confidenceIcon)
                        .font(.caption2)
                        .foregroundStyle(suggestion.isHighConfidence ? .green : .orange)

                    Text(suggestion.similarityPercentage)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Spacer()
                }

                Text(suggestion.sourceText)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let firstTranslation = suggestion.translations.first {
                    Text("\(firstTranslation.languageName): \(firstTranslation.text)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(12)
            .frame(width: 200)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TranslationView(initialText: .constant(""))
}
