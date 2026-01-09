//
//  LanguageSelectionView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct LanguageSelectionView: View {
    @Binding var selectedLanguages: Set<Locale.Language>
    @State private var searchText = ""
    @State private var service = TranslationService()
    @State private var supportedLanguages: [Locale.Language] = []
    @State private var installedLanguages: Set<Locale.Language> = []
    @State private var isLoading = true
    @State private var showOnlyInstalled = false
    @Environment(\.dismiss) private var dismiss

    /// List of supported translation languages from Translation framework
    private var availableLanguages: [Locale.Language] {
        let languages = showOnlyInstalled
            ? supportedLanguages.filter { installedLanguages.contains($0) }
            : supportedLanguages

        // Sort: installed first, then alphabetically
        return languages.sorted { language1, language2 in
            let installed1 = installedLanguages.contains(language1)
            let installed2 = installedLanguages.contains(language2)

            if installed1 != installed2 {
                return installed1 // installed languages first
            }
            return languageName(for: language1) < languageName(for: language2)
        }
    }

    private var filteredLanguages: [Locale.Language] {
        if searchText.isEmpty {
            return availableLanguages
        }
        return availableLanguages.filter { language in
            languageName(for: language).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading languages...")
                } else {
                    List {
                        Section {
                            Toggle("Show only installed languages", isOn: $showOnlyInstalled)
                        }

                        Section {
                            ForEach(filteredLanguages, id: \.self) { language in
                                Button {
                                    toggleLanguage(language)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(languageName(for: language))
                                                .foregroundStyle(.primary)

                                            if !installedLanguages.contains(language) {
                                                Text("Download required")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        HStack(spacing: 12) {
                                            // Installation status indicator
                                            if installedLanguages.contains(language) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(.green)
                                                    .font(.caption)
                                            } else {
                                                Image(systemName: "arrow.down.circle")
                                                    .foregroundStyle(.orange)
                                                    .font(.caption)
                                            }

                                            // Selection checkmark
                                            if selectedLanguages.contains(language) {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.blue)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            if showOnlyInstalled {
                                Text("Installed Languages (\(installedLanguages.count))")
                            } else {
                                Text("All Supported Languages (\(supportedLanguages.count))")
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search languages")
                    .overlay {
                        if filteredLanguages.isEmpty && !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        } else if supportedLanguages.isEmpty {
                            ContentUnavailableView(
                                "No Languages Available",
                                systemImage: "globe.badge.chevron.backward",
                                description: Text("Translation framework did not return any supported languages. Please check your device settings.")
                            )
                        }
                    }
                }
            }
            .navigationTitle("Select Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSupportedLanguages()
            }
        }
    }

    // MARK: - Private Methods

    private func loadSupportedLanguages() async {
        isLoading = true

        // Get all supported languages
        supportedLanguages = await service.getSupportedLanguages()

        // Check which languages are installed
        // Use English as the reference language to check availability
        let referenceLanguage = Locale.Language(identifier: "en")
        var installed: Set<Locale.Language> = []

        for language in supportedLanguages {
            // Check if this language pair is installed
            let isInstalled = await service.isLanguageInstalled(
                from: referenceLanguage,
                to: language
            )
            if isInstalled {
                installed.insert(language)
            }
        }

        installedLanguages = installed

        isLoading = false
    }

    private func toggleLanguage(_ language: Locale.Language) {
        if selectedLanguages.contains(language) {
            selectedLanguages.remove(language)
        } else {
            selectedLanguages.insert(language)
        }
    }

    private func languageName(for language: Locale.Language) -> String {
        Locale.current.localizedString(forLanguageCode: language.minimalIdentifier)
            ?? language.minimalIdentifier
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedLanguages: Set<Locale.Language> = [
            Locale.Language(identifier: "es"),
            Locale.Language(identifier: "fr")
        ]

        var body: some View {
            LanguageSelectionView(selectedLanguages: $selectedLanguages)
        }
    }

    return PreviewWrapper()
}
