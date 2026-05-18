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
    @State private var showDownloadSheet = false
    @AppStorage("disabledLanguageCodes") private var disabledLanguageCodes: String = ""

    var body: some View {
        Group {
            if isLoadingLanguages {
                ProgressView("Loading languages...")
            } else if installedLanguages.count < 2 {
                EmptyStateView(
                    configuration: .insufficientLanguages(installedCount: installedLanguages.count) {
                        showDownloadSheet = true
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
        .onChange(of: disabledLanguageCodes) {
            Task { await loadInstalledLanguages() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .supportedLanguagesDidChange)) { _ in
            Task { await loadInstalledLanguages() }
        }
        .sheet(isPresented: $showDownloadSheet, onDismiss: { Task { await loadInstalledLanguages() } }) {
            NavigationStack {
                LanguageDownloadView()
            }
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
        let loadedLanguages = await service.installedLanguages()
        installedLanguages = SupportedLanguages.enabledLanguages(
            from: loadedLanguages,
            disabledLanguageCodes: disabledLanguageCodes
        )
        isLoadingLanguages = false
    }

}

#Preview {
    ContentView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
