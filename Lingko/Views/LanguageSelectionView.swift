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
    @State private var installedLanguages: Set<Locale.Language> = []
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    private let minimumLanguageCount = 2

    /// Use curated list of supported languages
    private var availableLanguages: [LanguageInfo] {
        // Sort: installed first, then alphabetically
        return SupportedLanguages.all.sorted { lang1, lang2 in
            let installed1 = installedLanguages.contains(lang1.language)
            let installed2 = installedLanguages.contains(lang2.language)

            if installed1 != installed2 {
                return installed1 // installed languages first
            }
            return lang1.name < lang2.name
        }
    }

    private var filteredLanguages: [LanguageInfo] {
        if searchText.isEmpty {
            return availableLanguages
        }
        return availableLanguages.filter { languageInfo in
            languageInfo.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading languages...")
                } else {
                    List {
                        if selectedLanguages.count <= minimumLanguageCount {
                            Section {
                                HStack(spacing: 8) {
                                    Image(systemName: "info.circle.fill")
                                        .foregroundStyle(.blue)
                                    Text("At least \(minimumLanguageCount) languages must be selected")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        Section {
                            ForEach(filteredLanguages) { languageInfo in
                                let language = languageInfo.language
                                let isSelected = selectedLanguages.contains(language)
                                let canDeselect = selectedLanguages.count > minimumLanguageCount

                                Button {
                                    toggleLanguage(language, canDeselect: canDeselect)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(languageInfo.name)
                                                .foregroundStyle(.primary)

                                            if !installedLanguages.contains(language) {
                                                Text("Download required")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        HStack(spacing: 12) {
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(canDeselect ? .blue : .gray)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isSelected && !canDeselect)
                                .opacity((isSelected && !canDeselect) ? 0.6 : 1.0)
                            }
                        } header: {
                            Text("\(SupportedLanguages.all.count) languages")
                        } footer: {
                            if selectedLanguages.count == minimumLanguageCount {
                                Text("You have the minimum number of languages selected. Add more to enable deselection.")
                                    .font(.caption)
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search languages")
                    .overlay {
                        if filteredLanguages.isEmpty && !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
                }
            }
            .navigationTitle("Select Languages (\(selectedLanguages.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(isLoading || selectedLanguages.count < minimumLanguageCount)
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

        // Check which languages are installed
        // Use English as the reference language to check availability
        let referenceLanguage = Locale.Language(identifier: "en")
        var installed: Set<Locale.Language> = []

        for languageInfo in SupportedLanguages.all {
            let language = languageInfo.language

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

    private func toggleLanguage(_ language: Locale.Language, canDeselect: Bool) {
        if selectedLanguages.contains(language) {
            // Only allow deselection if we have more than minimum
            if canDeselect {
                selectedLanguages.remove(language)
            }
        } else {
            selectedLanguages.insert(language)
        }
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
