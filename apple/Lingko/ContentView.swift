//
//  ContentView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var loadedHistoryText = ""
    @State private var pasteTrigger = UUID()

    var body: some View {
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
}

#Preview {
    ContentView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
