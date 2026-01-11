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

    /// Downloaded languages only
    private var downloadedLanguages: [LanguageInfo] {
        SupportedLanguages.all.filter { languageInfo in
            installedLanguages.contains(languageInfo.language)
        }.sorted { $0.name < $1.name }
    }
    
    /// Not downloaded languages
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
            Group {
                if isLoading {
                    ProgressView("Loading languages...")
                } else {
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

                        // Downloaded languages section
                        if !filteredDownloadedLanguages.isEmpty {
                            Section {
                                ForEach(filteredDownloadedLanguages) { languageInfo in
                                    let language = languageInfo.language
                                    let isSelected = selectedLanguages.contains(language)
                                    let canDeselect = selectedLanguages.count > minimumLanguageCount

                                    Button {
                                        toggleLanguage(language, canDeselect: canDeselect)
                                    } label: {
                                        HStack {
                                            Text(languageInfo.name)
                                                .foregroundStyle(.primary)

                                            Spacer()

                                            if isSelected {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(canDeselect ? .blue : .gray)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isSelected && !canDeselect)
                                    .opacity((isSelected && !canDeselect) ? 0.6 : 1.0)
                                }
                            } header: {
                                Text("Downloaded Languages (\(downloadedLanguages.count))")
                            } footer: {
                                if selectedLanguages.count == minimumLanguageCount {
                                    Text("You have the minimum number of languages selected. Add more to enable deselection.")
                                        .font(.caption)
                                }
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
                                Text("Available After Download (\(notDownloadedLanguages.count))")
                            }
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search languages")
                    .overlay {
                        if filteredDownloadedLanguages.isEmpty && filteredNotDownloadedLanguages.isEmpty && !searchText.isEmpty {
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
