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
    case unsupported
    case error(String)
}

struct LanguageDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    let showsDoneButton: Bool

    @AppStorage("disabledLanguageCodes") private var disabledLanguageCodes: String = ""
    @State private var translationService = TranslationService()
    @State private var states: [String: DownloadState] = [:]
    @State private var supportedLanguages: [Locale.Language] = []
    @State private var isLoading = true
    @State private var downloadQueue: [LanguageInfo] = []
    @State private var currentDownload: LanguageInfo?
    @State private var downloadConfig: TranslationSession.Configuration?

    init(showsDoneButton: Bool = true) {
        self.showsDoneButton = showsDoneButton
    }

    var body: some View {
        List {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else {
                let installed = installedLanguages
                let available = availableLanguages

                if !installed.isEmpty {
                    Section {
                        ForEach(installed) { lang in
                            languageRow(lang)
                        }
                    } header: {
                        Text("Installed")
                    } footer: {
                        Text("At least two languages must remain enabled.")
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
        .navigationTitle("Languages")
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await loadStatuses() }
        .translationTask(downloadConfig) { session in
            guard let lang = currentDownload else { return }
            nonisolated(unsafe) let session = session
            do {
                try await session.prepareTranslation()
                states[lang.code] = .installed
                setLanguage(lang, isEnabled: true)
                notifyLanguagesChanged()
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

    // MARK: - Computed Properties

    private var languageInfos: [LanguageInfo] {
        SupportedLanguages.languageInfos(for: supportedLanguages)
    }

    private var installedLanguages: [LanguageInfo] {
        languageInfos.filter { lang in
            isEnglish(lang) || stateFor(lang) == .installed
        }.sorted { $0.name < $1.name }
    }

    private var availableLanguages: [LanguageInfo] {
        languageInfos.filter { lang in
            !isEnglish(lang) && stateFor(lang) != .installed
        }.sorted { $0.name < $1.name }
    }

    private var disabledCodes: Set<String> {
        SupportedLanguages.disabledLanguageCodeSet(from: disabledLanguageCodes)
    }

    private var enabledCount: Int {
        installedLanguages.filter { !disabledCodes.contains($0.code) }.count
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
            Toggle("", isOn: binding(for: lang))
                .labelsHidden()
                .disabled(isToggleDisabled(for: lang))
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
        case .unsupported:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func stateFor(_ lang: LanguageInfo) -> DownloadState {
        if isEnglish(lang) { return .installed }
        guard isFrameworkSupported(lang) else { return .unsupported }
        return states[lang.code] ?? .supported
    }

    private func isFrameworkSupported(_ lang: LanguageInfo) -> Bool {
        isEnglish(lang) || translationService.isLanguageSupported(lang.language, in: supportedLanguages)
    }

    private func isEnglish(_ lang: LanguageInfo) -> Bool {
        translationService.isSameLanguage(lang.language, Locale.Language(identifier: "en"))
    }

    private func binding(for lang: LanguageInfo) -> Binding<Bool> {
        Binding(
            get: { !disabledCodes.contains(lang.code) },
            set: { isEnabled in
                setLanguage(lang, isEnabled: isEnabled)
            }
        )
    }

    private func isToggleDisabled(for lang: LanguageInfo) -> Bool {
        !disabledCodes.contains(lang.code) && enabledCount <= 2
    }

    private func setLanguage(_ lang: LanguageInfo, isEnabled: Bool) {
        var updatedDisabledCodes = disabledCodes

        if isEnabled {
            updatedDisabledCodes.remove(lang.code)
        } else {
            guard enabledCount > 2 else { return }
            updatedDisabledCodes.insert(lang.code)
        }

        disabledLanguageCodes = SupportedLanguages.storageValue(
            forDisabledLanguageCodes: updatedDisabledCodes
        )
        notifyLanguagesChanged()
    }

    private func notifyLanguagesChanged() {
        NotificationCenter.default.post(name: .supportedLanguagesDidChange, object: nil)
    }

    // MARK: - Download Logic

    private func enqueue(_ lang: LanguageInfo) {
        guard isFrameworkSupported(lang) else { return }
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
        let english = Locale.Language(identifier: "en")
        let loadedSupportedLanguages = await translationService.getSupportedLanguages()
        supportedLanguages = loadedSupportedLanguages

        for lang in SupportedLanguages.languageInfos(for: loadedSupportedLanguages) where !isEnglish(lang) {
            guard translationService.isLanguageSupported(lang.language, in: loadedSupportedLanguages) else {
                states[lang.code] = .unsupported
                continue
            }

            let status = await translationService.getLanguageStatus(
                from: english,
                to: lang.language,
                supportedLanguages: loadedSupportedLanguages
            )
            switch status {
            case .installed:
                states[lang.code] = .installed
            case .supported:
                states[lang.code] = .supported
            case .unsupported:
                states[lang.code] = .unsupported
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
    NavigationStack {
        LanguageDownloadView()
    }
}
