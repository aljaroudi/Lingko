//
//  LanguageDownloadView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import Translation

private enum DownloadState: Equatable {
    case supported
    case queued
    case downloading
    case installed
    case error(String)
}

struct LanguageDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var states: [String: DownloadState] = [:]
    @State private var isLoading = true
    @State private var downloadQueue: [LanguageInfo] = []
    @State private var currentDownload: LanguageInfo?
    @State private var downloadConfig: TranslationSession.Configuration?

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
                                languageRow(lang)
                            }
                        }
                    }

                    if !available.isEmpty {
                        Section("Available") {
                            ForEach(available) { lang in
                                languageRow(lang)
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
            .translationTask(downloadConfig) { session in
                guard let lang = currentDownload else { return }
                nonisolated(unsafe) let session = session
                do {
                    try await session.prepareTranslation()
                    states[lang.code] = .installed
                } catch {
                    states[lang.code] = .error(error.localizedDescription)
                }
                // Clear current download — onChange below picks up the next item
                currentDownload = nil
                downloadConfig = nil
            }
            .onChange(of: currentDownload) { oldValue, newValue in
                // When a download finishes (transitions to nil) and queue has items, start next
                if oldValue != nil && newValue == nil && !downloadQueue.isEmpty {
                    startNextDownload()
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var installedLanguages: [LanguageInfo] {
        SupportedLanguages.all.filter { lang in
            lang.code == "en" || stateFor(lang) == .installed
        }.sorted { $0.name < $1.name }
    }

    private var availableLanguages: [LanguageInfo] {
        SupportedLanguages.all.filter { lang in
            lang.code != "en" && stateFor(lang) != .installed
        }.sorted { $0.name < $1.name }
    }

    // MARK: - Row Views

    @ViewBuilder
    private func languageRow(_ lang: LanguageInfo) -> some View {
        HStack {
            Text(lang.name)
            Spacer()
            stateIndicator(for: lang)
        }
    }

    @ViewBuilder
    private func stateIndicator(for lang: LanguageInfo) -> some View {
        switch stateFor(lang) {
        case .installed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .downloading:
            ProgressView()
                .controlSize(.small)
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .error(let message):
            Button {
                enqueue(lang)
            } label: {
                Label("Retry", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            .labelStyle(.iconOnly)
            .help(message)
        case .supported:
            Button {
                enqueue(lang)
            } label: {
                Label("Download", systemImage: "arrow.down.circle")
            }
            .labelStyle(.iconOnly)
            .controlSize(.small)
        }
    }

    // MARK: - Helpers

    private func stateFor(_ lang: LanguageInfo) -> DownloadState {
        if lang.code == "en" { return .installed }
        return states[lang.code] ?? .supported
    }

    // MARK: - Download Logic

    private func enqueue(_ lang: LanguageInfo) {
        guard stateFor(lang) == .supported || states[lang.code]?.isError == true else { return }
        states[lang.code] = .queued
        downloadQueue.append(lang)
        if currentDownload == nil {
            startNextDownload()
        }
    }

    private func startNextDownload() {
        guard !downloadQueue.isEmpty else { return }
        let next = downloadQueue.removeFirst()
        currentDownload = next
        states[next.code] = .downloading
        downloadConfig = .init(
            source: Locale.Language(identifier: "en"),
            target: next.language
        )
    }

    // MARK: - Status Loading

    private func loadStatuses() async {
        let availability = LanguageAvailability()
        let english = Locale.Language(identifier: "en")

        for lang in SupportedLanguages.all where lang.code != "en" {
            let status = await availability.status(from: english, to: lang.language)
            switch status {
            case .installed:
                states[lang.code] = .installed
            case .supported:
                states[lang.code] = .supported
            case .unsupported:
                break
            @unknown default:
                break
            }
        }

        isLoading = false
    }
}

// MARK: - DownloadState helpers

private extension DownloadState {
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
}

#Preview {
    LanguageDownloadView()
}
