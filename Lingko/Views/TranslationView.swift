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
    @State private var inputText: String
    @State private var translations: [TranslationResult] = []
    @State private var selectedLanguages: Set<Locale.Language> = LanguagePreferences.loadSelectedLanguages()
    @State private var isTranslating = false
    @State private var showLanguageSelection = false
    @State private var showImageTranslation = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var debounceTask: Task<Void, Never>?
    @State private var detectedLanguage: String?
    @State private var sourceRomanization: String?
    @FocusState private var isInputFocused: Bool
    @State private var speechRate: Float = 0.5
    @State private var translationMemorySuggestions: [TranslationMemorySuggestion] = []

    // Feature toggles
    @State private var includeLinguisticAnalysis = false
    @State private var includeRomanization = true
    @State private var autoSaveToHistory = true

    private let debounceDelay: Duration = .milliseconds(500)

    init(initialText: String = "") {
        _inputText = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
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
            .navigationTitle("Lingko")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
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
            .sheet(isPresented: $showImageTranslation) {
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
                }
            }
            .onChange(of: selectedLanguages) { _, newLanguages in
                LanguagePreferences.saveSelectedLanguages(newLanguages)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    await loadImage(from: newItem)
                }
            }
            .onDisappear {
                audioService.stop()
            }
        }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Enter Text")
                    .font(.headline)
                    .foregroundStyle(.primary)

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

            TextEditor(text: $inputText)
                .frame(minHeight: 100, maxHeight: 200)
                .padding(8)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
                .focused($isInputFocused)
                .onChange(of: inputText) { _, newValue in
                    handleTextChange(newValue)
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

            // Feature toggles
            VStack(spacing: 8) {
                Toggle(isOn: $includeRomanization) {
                    Label("Romanization", systemImage: "textformat.abc")
                        .font(.subheadline)
                }
                .onChange(of: includeRomanization) { _, _ in
                    if !inputText.isEmpty {
                        handleTextChange(inputText)
                    }
                }

                Toggle(isOn: $includeLinguisticAnalysis) {
                    Label("Linguistic Analysis", systemImage: "brain")
                        .font(.subheadline)
                }
                .onChange(of: includeLinguisticAnalysis) { _, _ in
                    if !inputText.isEmpty {
                        handleTextChange(inputText)
                    }
                }

                Toggle(isOn: $autoSaveToHistory) {
                    Label("Auto-save to History", systemImage: "clock.arrow.circlepath")
                        .font(.subheadline)
                }
            }
            .padding(.vertical, 8)

            // Speech rate control
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label("Speech Rate", systemImage: "gauge.with.dots.needle.33percent")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(String(format: "%.1fx", speechRate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $speechRate, in: 0.3...0.7, step: 0.1)
                    .tint(.accentColor)
            }
            .padding(.vertical, 4)

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
        if translations.isEmpty && !inputText.isEmpty && !isTranslating {
            ContentUnavailableView(
                "No Translations",
                systemImage: "text.bubble",
                description: Text("Try selecting different languages or entering different text")
            )
        } else if translations.isEmpty {
            ContentUnavailableView(
                "Ready to Translate",
                systemImage: "character.bubble",
                description: Text("Enter text above to see translations")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(translations) { result in
                        TranslationResultRow(
                            result: result,
                            audioService: audioService,
                            aiService: aiService,
                            speechRate: speechRate
                        )
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(.systemGroupedBackground))
        }
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

        // Detect language
        let (language, _) = service.detectLanguage(for: text)
        if let language {
            detectedLanguage = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier)
                ?? language.minimalIdentifier
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
                await MainActor.run {
                    selectedImage = image
                    showImageTranslation = true
                }
            }
        } catch {
            print("Failed to load image: \(error)")
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
    TranslationView()
}
