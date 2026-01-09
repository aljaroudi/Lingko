//
//  TranslationView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct TranslationView: View {
    @State private var service = TranslationService()
    @State private var inputText = ""
    @State private var translations: [TranslationResult] = []
    @State private var selectedLanguages: Set<Locale.Language> = []
    @State private var isTranslating = false
    @State private var showLanguageSelection = false
    @State private var debounceTask: Task<Void, Never>?
    @State private var detectedLanguage: String?

    private let debounceDelay: Duration = .milliseconds(500)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Input section
                inputSection
                    .padding()
                    .background(Color(.systemGroupedBackground))

                Divider()

                // Results section
                resultsSection
            }
            .navigationTitle("Lingko")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    languageSelectionButton
                }
            }
            .sheet(isPresented: $showLanguageSelection) {
                LanguageSelectionView(selectedLanguages: $selectedLanguages)
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
                .onChange(of: inputText) { _, newValue in
                    handleTextChange(newValue)
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
                        TranslationResultRow(result: result)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
        }
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
            isTranslating = false
            return
        }

        // Create new debounced task
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

        // Perform translation
        let results = await service.translateToAll(
            text: text,
            from: language,
            to: selectedLanguages
        )

        // Update UI
        translations = results
        isTranslating = false
    }
}

#Preview {
    TranslationView()
}
