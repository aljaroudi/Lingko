//
//  LanguageDownloadView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import Translation

struct LanguageDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var downloadConfig: TranslationSession.Configuration?
    @State private var statuses: [String: LanguageAvailability.Status] = [:]
    @State private var isLoading = true
    @State private var isDownloading = false

    var body: some View {
        NavigationStack {
            List {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowSeparator(.hidden)
                } else {
                    let installed = installedLanguages
                    let available = availableLanguages

                    if !installed.isEmpty {
                        Section("Installed") {
                            ForEach(installed) { lang in
                                HStack {
                                    Text(lang.name)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }

                    if !available.isEmpty {
                        Section("Available") {
                            ForEach(available) { lang in
                                HStack {
                                    Text(lang.name)
                                    Spacer()
                                    Button("Download", systemImage: "arrow.down.circle") {
                                        downloadLanguage(lang)
                                    }
                                    .labelStyle(.iconOnly)
                                    .controlSize(.small)
                                    .disabled(isDownloading)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Download Languages")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await loadStatuses() }
        }
        .translationTask(downloadConfig) { session in
            nonisolated(unsafe) let session = session
            do { try await session.prepareTranslation() } catch {}
            isDownloading = false
            downloadConfig = nil
            await loadStatuses()
        }
    }

    private var installedLanguages: [LanguageInfo] {
        SupportedLanguages.all.filter { lang in
            lang.code == "en" || statuses[lang.code] == .installed
        }.sorted { $0.name < $1.name }
    }

    private var availableLanguages: [LanguageInfo] {
        SupportedLanguages.all.filter { lang in
            lang.code != "en" && statuses[lang.code] == .supported
        }.sorted { $0.name < $1.name }
    }

    private func downloadLanguage(_ lang: LanguageInfo) {
        isDownloading = true
        downloadConfig = TranslationSession.Configuration(
            source: Locale.Language(identifier: "en"),
            target: lang.language
        )
    }

    private func loadStatuses() async {
        let availability = LanguageAvailability()
        let english = Locale.Language(identifier: "en")
        var result: [String: LanguageAvailability.Status] = [:]

        for lang in SupportedLanguages.all where lang.code != "en" {
            let status = await availability.status(from: english, to: lang.language)
            result[lang.code] = status
        }

        statuses = result
        isLoading = false
    }
}

#Preview {
    LanguageDownloadView()
}
