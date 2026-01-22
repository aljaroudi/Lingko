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
                #if os(macOS)
                .onReceive(NotificationCenter.default.publisher(for: .pasteAndTranslate)) { _ in
                    handlePasteAndTranslate()
                }
                .onReceive(NotificationCenter.default.publisher(for: .translateText)) { notification in
                    if let text = notification.object as? String {
                        loadedHistoryText = text
                        selectedTab = 0
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showHistory"))) { _ in
                    selectedTab = 1
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("showSettings"))) { _ in
                    // Settings is handled within TranslationView
                    selectedTab = 0
                }
                #endif
                #if os(iOS)
                .sensoryFeedback(.impact(weight: .medium), trigger: pasteTrigger)
                #endif
            }
        }
        .task {
            await loadInstalledLanguages()
        }
    }

    private func checkForPasteAction() {
        #if os(iOS)
        if AppDelegate.shouldPasteAndTranslate {
            AppDelegate.shouldPasteAndTranslate = false
            handlePasteAndTranslate()
        }
        #endif
    }

    private func handlePasteAndTranslate() {
        if let clipboardText = PlatformUtils.readFromPasteboard(), !clipboardText.isEmpty {
            loadedHistoryText = clipboardText
            selectedTab = 0
            #if os(iOS)
            pasteTrigger = UUID()
            #endif
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
        #if os(iOS)
        if let url = URL(string: "App-prefs:TRANSLATE") {
            UIApplication.shared.open(url) { success in
                if !success {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
        }
        #elseif os(macOS)
        PlatformUtils.openSystemSettings(urlString: "x-apple.systempreferences:com.apple.Translate-Settings")
        #endif
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
