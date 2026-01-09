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

    var body: some View {
        TabView(selection: $selectedTab) {
            TranslationView(initialText: loadedHistoryText)
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
