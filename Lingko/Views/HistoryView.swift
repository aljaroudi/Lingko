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
                        .background(Color(.systemGroupedBackground))
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
                Section(section) {
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
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                            let displayCount = isExpanded ? translations.count : min(3, translations.count)

                            ForEach(Array(translations.prefix(displayCount).enumerated()), id: \.offset) { _, trans in
                                TranslationEntryView(entry: trans)
                            }

                            // Show more/less button if more than 2 translations
                            if translations.count > 3 {
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

            // Tags section
            if let tags = translation.tags, !tags.isEmpty {
                HStack(spacing: 8) {
                    ForEach(tags) { tag in
                        TagChip(tag: tag)
                    }

                    Spacer()

                    Button(action: onEditTags) {
                        Image(systemName: "tag")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.leading, 52)
                .padding(.trailing, 12)
                .padding(.top, 4)
                .padding(.bottom, 8)
            } else {
                // Show "Add tags" button if no tags
                Button(action: onEditTags) {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.caption2)
                        Text("Add tags")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 52)
                .padding(.top, 4)
                .padding(.bottom, 8)
            }
        }
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
            .background(isSelected ? chipColor : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: SavedTranslation.self, inMemory: true)
}
