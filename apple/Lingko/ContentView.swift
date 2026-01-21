//
//  ContentView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData
import Translation

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var loadedHistoryText = ""
    @State private var pasteTrigger = UUID()
    @State private var installedLanguages: Set<Locale.Language> = []
    @State private var isLoadingLanguages = true

    var body: some View {
        Group {
            if isLoadingLanguages {
                ProgressView("Loading languages...")
            } else if installedLanguages.count < 2 {
                EmptyStateView(
                    configuration: .insufficientLanguages(installedCount: installedLanguages.count) {
                        openTranslateSettings()
                    }
                )
            } else {
                TabView(selection: $selectedTab) {
                    TranslationView(initialText: $loadedHistoryText)
                        .tabItem {
                            Label("Translate", systemImage: "character.bubble")
                        }
                        .tag(0)

                    HistoryView(onLoadTranslation: { text in
                        loadedHistoryText = text
                        selectedTab = 0
                    })
                    .tabItem {
                        Label("History", systemImage: "clock")
                    }
                    .tag(1)
                }
                .onAppear {
                    checkForPasteAction()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PasteAndTranslate"))) { _ in
                    handlePasteAndTranslate()
                }
                .sensoryFeedback(.impact(weight: .medium), trigger: pasteTrigger)
            }
        }
        .task {
            await loadInstalledLanguages()
        }
    }

    private func checkForPasteAction() {
        if AppDelegate.shouldPasteAndTranslate {
            AppDelegate.shouldPasteAndTranslate = false
            handlePasteAndTranslate()
        }
    }

    private func handlePasteAndTranslate() {
        if let clipboardText = UIPasteboard.general.string, !clipboardText.isEmpty {
            loadedHistoryText = clipboardText
            selectedTab = 0
            pasteTrigger = UUID()
        }
    }

    private func loadInstalledLanguages() async {
        let service = TranslationService()
        var installed: Set<Locale.Language> = []

        // Use a reference language to check installation status
        // We'll use English as the reference since it's commonly installed
        let referenceLanguage = Locale.Language(identifier: "en")

        // Check each language in our curated list to see if it's actually installed
        for languageInfo in SupportedLanguages.all {
            let language = languageInfo.language

            // Check if this language is installed by checking translation pair availability
            let status = await service.getLanguageStatus(from: referenceLanguage, to: language)

            if status == .installed {
                installed.insert(language)
            }

            // Also check the reverse direction and add reference language itself
            if language.minimalIdentifier == referenceLanguage.minimalIdentifier {
                installed.insert(language)
            }
        }

        installedLanguages = installed
        isLoadingLanguages = false
    }

    private func openTranslateSettings() {
        if let url = URL(string: "App-prefs:TRANSLATE") {
            UIApplication.shared.open(url) { success in
                if !success {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
