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
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)])
    private var allTags: [Tag]

    @State private var historyService = HistoryService()
    @State private var tagService = TagService()
    @State private var searchText = ""
    @State private var showFavoritesOnly = false
    @State private var selectedTagFilter: Tag?
    @State private var showClearAllAlert = false
    @State private var showTagManagement = false
    @State private var selectedTranslationForTagEdit: SavedTranslation?
    @State private var deletionTrigger = UUID()
    @State private var favoriteToggleTrigger = UUID()

    // Callback for loading translation
    var onLoadTranslation: ((String) -> Void)?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tag filter bar
                if !allTags.isEmpty {
                    tagFilterBar
                        .padding(.vertical, 8)
                        .background(Color.platformGroupedBackground)
                }

                Divider()

                // History list
                Group {
                    if filteredHistory.isEmpty {
                        emptyStateView
                    } else {
                        historyList
                    }
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

                        Button {
                            showTagManagement = true
                        } label: {
                            Label("Manage Tags", systemImage: "tag")
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
            }
            .alert("Clear All History", isPresented: $showClearAllAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Clear All", role: .destructive) {
                    historyService.clearAll(context: modelContext)
                }
            } message: {
                Text("Are you sure you want to delete all translation history? This action cannot be undone.")
            }
            .sheet(item: $selectedTranslationForTagEdit) { translation in
                TagEditorView(translation: translation)
            }
            .sheet(isPresented: $showTagManagement) {
                TagManagementView()
            }
            .navigationDestination(for: HistoryAIInsightsDestination.self) { destination in
                AIInsightsDetailView(destination: destination)
            }
            .onAppear {
                // Initialize default tags if they don't exist
                tagService.initializeDefaultTags(context: modelContext)
            }
            .sensoryFeedback(.impact(weight: .medium), trigger: deletionTrigger)
            .sensoryFeedback(.success, trigger: favoriteToggleTrigger)
        }
    }

    // MARK: - Computed Properties

    private var filteredHistory: [SavedTranslation] {
        var results = allHistory

        // Filter by favorites
        if showFavoritesOnly {
            results = results.filter { $0.isFavorite }
        }

        // Filter by selected tag
        if let selectedTag = selectedTagFilter {
            results = results.filter { translation in
                translation.tags?.contains(where: { $0.id == selectedTag.id }) ?? false
            }
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
    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All" chip to clear filter
                TagFilterChip(
                    isSelected: selectedTagFilter == nil,
                    name: "All",
                    icon: "circle.grid.2x2",
                    color: nil
                ) {
                    selectedTagFilter = nil
                }

                // Tag chips
                ForEach(allTags) { tag in
                    TagFilterChip(
                        isSelected: selectedTagFilter?.id == tag.id,
                        name: tag.name,
                        icon: tag.icon,
                        color: tag.color
                    ) {
                        if selectedTagFilter?.id == tag.id {
                            selectedTagFilter = nil
                        } else {
                            selectedTagFilter = tag
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var historyList: some View {
        List {
            ForEach(groupedHistory, id: \.0) { section, translations in
                Section {
                    ForEach(translations) { translation in
                        HistoryRow(
                            translation: translation,
                            onToggleFavorite: {
                                historyService.toggleFavorite(translation, context: modelContext)
                            },
                            onLoad: {
                                onLoadTranslation?(translation.sourceText)
                            },
                            onEditTags: {
                                selectedTranslationForTagEdit = translation
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deletionTrigger = UUID()
                                historyService.deleteTranslation(translation, context: modelContext)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                favoriteToggleTrigger = UUID()
                                historyService.toggleFavorite(translation, context: modelContext)
                            } label: {
                                Label(
                                    translation.isFavorite ? "Unfavorite" : "Favorite",
                                    systemImage: translation.isFavorite ? "star.slash" : "star.fill"
                                )
                            }
                            .tint(.yellow)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                } header: {
                    Text(section)
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.platformGroupedBackground)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        if showFavoritesOnly {
            EmptyStateView(
                configuration: EmptyStateConfiguration(
                    iconName: "star.slash",
                    iconColor: .yellow,
                    title: "No favorites yet",
                    message: "You haven't favorited any translations yet",
                    action: EmptyStateAction(
                        title: "Show All",
                        iconName: "clock",
                        handler: {
                            showFavoritesOnly = false
                        }
                    )
                )
            )
        } else if !searchText.isEmpty {
            EmptyStateView(configuration: .searchEmpty(query: searchText))
        } else {
            EmptyStateView(configuration: .historyEmpty)
        }
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let translation: SavedTranslation
    let onToggleFavorite: () -> Void
    let onLoad: () -> Void
    let onEditTags: () -> Void

    @State private var sourceAudioService = AudioService()
    @State private var isSpeakingSource = false
    @AppStorage("defaultSpeechRate") private var speechRate: Double = 0.5

    private var sourceLanguage: Locale.Language? {
        translation.sourceLanguageCode.map { Locale.Language(identifier: $0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Source block
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(translation.sourceLanguageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(translation.sourceText)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button(action: toggleSourceSpeech) {
                    Image(systemName: isSpeakingSource ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSpeakingSource ? "Stop speaking" : "Speak source")
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture { onLoad() }

            // Target blocks
            if let entries = translation.decodedTranslations, !entries.isEmpty {
                ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
                    Divider()
                    TargetBlock(
                        entry: entry,
                        source: translation,
                        isFavorite: translation.isFavorite,
                        onToggleFavorite: onToggleFavorite,
                        onEditTags: onEditTags
                    )
                }
            }

            // Tags (compact, translation-level)
            if let tags = translation.tags, !tags.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(tags) { tag in TagChip(tag: tag) }
                        Button(action: onEditTags) {
                            Image(systemName: "tag")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color.platformBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func toggleSourceSpeech() {
        guard let lang = sourceLanguage else { return }
        if isSpeakingSource {
            sourceAudioService.stop()
            isSpeakingSource = false
        } else {
            sourceAudioService.speak(text: translation.sourceText, language: lang, rate: Float(speechRate))
            isSpeakingSource = true
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                while isSpeakingSource && sourceAudioService.isPlaying {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                isSpeakingSource = false
            }
        }
    }
}

// MARK: - Target Block

private struct TargetBlock: View {
    let entry: TranslationEntry
    let source: SavedTranslation
    let isFavorite: Bool
    let onToggleFavorite: () -> Void
    let onEditTags: () -> Void

    @State private var audioService = AudioService()
    @State private var isSpeaking = false
    @State private var showCopyConfirmation = false
    @AppStorage("defaultSpeechRate") private var speechRate: Double = 0.5

    private var language: Locale.Language { Locale.Language(identifier: entry.languageCode) }

    private var layoutDirection: LayoutDirection {
        Script.detect(from: language).isRTL ? .rightToLeft : .leftToRight
    }

    private var detailDestination: HistoryAIInsightsDestination {
        HistoryAIInsightsDestination(
            sourceText: source.sourceText,
            sourceLanguageCode: source.sourceLanguageCode,
            languageCode: entry.languageCode,
            translationText: entry.text,
            romanization: entry.romanization,
            detectionConfidence: source.detectionConfidence
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Translation text + play
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.languageName)
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                    Text(entry.text)
                        .font(.title2)
                        .foregroundStyle(.accent)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
                        .environment(\.layoutDirection, layoutDirection)
                    if let romanization = entry.romanization {
                        Text(romanization)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .textSelection(.enabled)
                    }
                }
                Button(action: toggleSpeech) {
                    Image(systemName: isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSpeaking ? "Stop speaking" : "Speak translation")
            }

            // Action row
            HStack(spacing: 20) {
                NavigationLink(value: detailDestination) {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.primary.opacity(0.4))
                }
                .accessibilityLabel("View details")

                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? Color.yellow : Color.accentColor)
                }
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button(action: copyToClipboard) {
                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(.accent)
                }
                .accessibilityLabel(showCopyConfirmation ? "Copied" : "Copy translation")

                Spacer(minLength: 0)
            }
            .buttonStyle(.plain)
            .font(.title3)
        }
        .padding()
        .sensoryFeedback(.success, trigger: showCopyConfirmation)
    }

    private func toggleSpeech() {
        if isSpeaking {
            audioService.stop()
            isSpeaking = false
        } else {
            audioService.speak(text: entry.text, language: language, rate: Float(speechRate))
            isSpeaking = true
            Task {
                try? await Task.sleep(for: .milliseconds(100))
                while isSpeaking && audioService.isPlaying {
                    try? await Task.sleep(for: .milliseconds(100))
                }
                isSpeaking = false
            }
        }
    }

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = entry.text
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.text, forType: .string)
        #endif
        withAnimation { showCopyConfirmation = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { showCopyConfirmation = false }
        }
    }
}

// MARK: - Tag Chip Components

private struct TagChip: View {
    let tag: Tag

    var chipColor: Color {
        if let hex = tag.color {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tag.icon)
                .font(.caption2)
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipColor.opacity(0.15))
        .foregroundStyle(chipColor)
        .clipShape(Capsule())
    }
}

private struct TagFilterChip: View {
    let isSelected: Bool
    let name: String
    let icon: String
    let color: String?
    let action: () -> Void

    var chipColor: Color {
        if let hex = color {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            #if os(iOS)
            .background(isSelected ? chipColor : Color(.systemGray5))
            #elseif os(macOS)
            .background(isSelected ? chipColor : Color.secondary.opacity(0.2))
            #endif
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation Destination

struct HistoryAIInsightsDestination: Hashable {
    let sourceText: String
    let sourceLanguageCode: String?
    let languageCode: String
    let translationText: String
    let romanization: String?
    let detectionConfidence: Double
}

#Preview {
    HistoryView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
