//
//  HistoryView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedTranslation.timestamp, order: .reverse)
    private var allHistory: [SavedTranslation]

    @State private var historyService = HistoryService()
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var showClearAllAlert = false
    @State private var showExportSheet = false

    // Callback for loading translation
    var onLoadTranslation: ((String) -> Void)?

    var body: some View {
        NavigationStack {
            Group {
                if filteredHistory.isEmpty {
                    emptyStateView
                } else {
                    historyList
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search translations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Toggle(isOn: $showFavoritesOnly) {
                            Label("Favorites Only", systemImage: "star.fill")
                        }

                        Divider()

                        Button(role: .destructive) {
                            showClearAllAlert = true
                        } label: {
                            Label("Clear All", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .secondaryAction) {
                    Button {
                        showExportSheet = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .disabled(filteredHistory.isEmpty)
                }
            }
            .alert("Clear All History", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    historyService.clearAll(context: modelContext)
                }
            } message: {
                Text("Are you sure you want to delete all translation history? This action cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView(history: filteredHistory)
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredHistory: [SavedTranslation] {
        var results = allHistory

        // Filter by favorites
        if showFavoritesOnly {
            results = results.filter { $0.isFavorite }
        }

        // Filter by search text
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let query = searchText.lowercased()
            results = results.filter { entry in
                // Search source text
                if entry.sourceText.lowercased().contains(query) {
                    return true
                }

                // Search source language
                if entry.sourceLanguageName.lowercased().contains(query) {
                    return true
                }

                // Search all translations
                if let translations = entry.decodedTranslations {
                    return translations.contains { translation in
                        translation.text.lowercased().contains(query) ||
                        translation.languageName.lowercased().contains(query) ||
                        (translation.romanization?.lowercased().contains(query) ?? false)
                    }
                }

                return false
            }
        }

        return results
    }

    private var groupedHistory: [(String, [SavedTranslation])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [SavedTranslation]] = [
            "Today": [],
            "Yesterday": [],
            "This Week": [],
            "Older": []
        ]

        for translation in filteredHistory {
            if calendar.isDateInToday(translation.timestamp) {
                groups["Today"]?.append(translation)
            } else if calendar.isDateInYesterday(translation.timestamp) {
                groups["Yesterday"]?.append(translation)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      translation.timestamp > weekAgo {
                groups["This Week"]?.append(translation)
            } else {
                groups["Older"]?.append(translation)
            }
        }

        return [
            ("Today", groups["Today"]!),
            ("Yesterday", groups["Yesterday"]!),
            ("This Week", groups["This Week"]!),
            ("Older", groups["Older"]!)
        ].filter { !$0.1.isEmpty }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.0) { section, translations in
                Section(section) {
                    ForEach(translations) { translation in
                        HistoryRow(
                            translation: translation,
                            onToggleFavorite: {
                                historyService.toggleFavorite(translation, context: modelContext)
                            },
                            onLoad: {
                                onLoadTranslation?(translation.sourceText)
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                historyService.deleteTranslation(translation, context: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                historyService.toggleFavorite(translation, context: modelContext)
                            } label: {
                                Label(
                                    translation.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: translation.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No History", systemImage: "clock")
        } description: {
            if showFavoritesOnly {
                Text("You haven't favorited any translations yet")
            } else if !searchText.isEmpty {
                Text("No translations match '\(searchText)'")
            } else {
                Text("Your translation history will appear here")
            }
        } actions: {
            if showFavoritesOnly {
                Button("Show All") {
                    showFavoritesOnly = false
                }
                .buttonStyle(.bordered)
            } else if !searchText.isEmpty {
                Button("Clear Search") {
                    searchText = ""
                }
                .buttonStyle(.bordered)
            }
        }
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let translation: SavedTranslation
    let onToggleFavorite: () -> Void
    let onLoad: () -> Void

    @State private var isExpanded = false

    var body: some View {
        Button(action: onLoad) {
            HStack(alignment: .top, spacing: 12) {
                // Favorite button
                Button(action: onToggleFavorite) {
                    Image(systemName: translation.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(translation.isFavorite ? .yellow : .gray)
                        .font(.title3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 8) {
                    // Header: source language and timestamp
                    HStack(spacing: 6) {
                        Text(translation.sourceLanguageName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("\(translation.translationCount) languages")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(translation.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }

                    // Source text
                    Text(translation.sourceText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    // Show translations
                    if let translations = translation.decodedTranslations {
                        let displayCount = isExpanded ? translations.count : min(2, translations.count)

                        ForEach(Array(translations.prefix(displayCount).enumerated()), id: \.offset) { _, trans in
                            TranslationEntryView(entry: trans)
                        }

                        // Show more/less button if more than 2 translations
                        if translations.count > 2 {
                            Button(action: { isExpanded.toggle() }) {
                                HStack(spacing: 4) {
                                    Text(isExpanded ? "Show less" : "Show \(translations.count - 2) more")
                                        .font(.caption)
                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.caption2)
                                }
                                .foregroundStyle(.blue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Translation Entry View

private struct TranslationEntryView: View {
    let entry: DataSchema.TranslationEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(entry.languageName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                Text(entry.text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Romanization (if available)
            if let romanization = entry.romanization {
                HStack(spacing: 4) {
                    Image(systemName: "textformat.abc")
                        .font(.caption2)
                    Text(romanization)
                        .font(.caption)
                        .italic()
                }
                .foregroundStyle(.tertiary)
            }

            // Sentiment (if available)
            if let sentiment = entry.sentimentDescription {
                HStack(spacing: 4) {
                    Image(systemName: sentimentIcon(for: entry.sentiment))
                        .font(.caption2)
                    Text(sentiment)
                        .font(.caption)
                }
                .foregroundStyle(sentimentColor(for: entry.sentiment))
            }
        }
        .padding(.leading, 8)
        .padding(.vertical, 2)
    }

    private func sentimentIcon(for sentiment: Double?) -> String {
        guard let sentiment else { return "circle" }
        if sentiment > 0.3 { return "face.smiling" }
        if sentiment < -0.3 { return "face.frowning" }
        return "circle"
    }

    private func sentimentColor(for sentiment: Double?) -> Color {
        guard let sentiment else { return .gray }
        if sentiment > 0.3 { return .green }
        if sentiment < -0.3 { return .red }
        return .gray
    }
}

// MARK: - Export View

private struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let history: [SavedTranslation]

    @State private var exportFormat: ExportFormat = .text
    @State private var exportedText = ""

    enum ExportFormat: String, CaseIterable {
        case text = "Text"
        case csv = "CSV"
        case json = "JSON"

        var fileExtension: String {
            switch self {
            case .text: return "txt"
            case .csv: return "csv"
            case .json: return "json"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Picker("Format", selection: $exportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    Text(generateExportText())
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .background(Color(.systemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                ShareLink(
                    item: generateExportText(),
                    preview: SharePreview(
                        "Translation History",
                        image: Image(systemName: "doc.text")
                    )
                ) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .navigationTitle("Export History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateExportText() -> String {
        switch exportFormat {
        case .text:
            return generateTextFormat()
        case .csv:
            return generateCSVFormat()
        case .json:
            return generateJSONFormat()
        }
    }

    private func generateTextFormat() -> String {
        var text = "Translation History\n"
        text += "Exported: \(Date().formatted())\n"
        text += String(repeating: "=", count: 50) + "\n\n"

        for (index, entry) in history.enumerated() {
            text += "[\(index + 1)] \(entry.timestamp.formatted())\n"
            text += "From: \(entry.sourceLanguageName)\n"
            text += "Source: \(entry.sourceText)\n"
            text += "\nTranslations (\(entry.translationCount)):\n"

            if let translations = entry.decodedTranslations {
                for translation in translations {
                    text += "  • \(translation.languageName): \(translation.text)\n"
                    if let romanization = translation.romanization {
                        text += "    Romanization: \(romanization)\n"
                    }
                    if let sentiment = translation.sentimentDescription {
                        text += "    Sentiment: \(sentiment)\n"
                    }
                }
            }

            text += "\n"
        }

        return text
    }

    private func generateCSVFormat() -> String {
        var csv = "Timestamp,Source Language,Source Text,Target Language,Translation,Romanization,Sentiment,Favorite\n"

        for entry in history {
            if let translations = entry.decodedTranslations {
                for translation in translations {
                    let fields = [
                        entry.timestamp.ISO8601Format(),
                        entry.sourceLanguageName,
                        escapeCSV(entry.sourceText),
                        translation.languageName,
                        escapeCSV(translation.text),
                        escapeCSV(translation.romanization ?? ""),
                        translation.sentimentDescription ?? "",
                        entry.isFavorite ? "Yes" : "No"
                    ]
                    csv += fields.joined(separator: ",") + "\n"
                }
            }
        }

        return csv
    }

    private func generateJSONFormat() -> String {
        let jsonArray = history.map { entry in
            var entryDict: [String: Any] = [
                "timestamp": entry.timestamp.ISO8601Format(),
                "sourceLanguage": entry.sourceLanguageName,
                "sourceText": entry.sourceText,
                "confidence": entry.detectionConfidence,
                "isFavorite": entry.isFavorite
            ]

            if let translations = entry.decodedTranslations {
                let translationsArray = translations.map { translation in
                    [
                        "targetLanguage": translation.languageName,
                        "text": translation.text,
                        "romanization": translation.romanization ?? "",
                        "sentiment": translation.sentimentDescription ?? ""
                    ] as [String: Any]
                }
                entryDict["translations"] = translationsArray
            }

            return entryDict
        }

        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }

        return "[]"
    }

    private func escapeCSV(_ text: String) -> String {
        if text.contains(",") || text.contains("\"") || text.contains("\n") {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
