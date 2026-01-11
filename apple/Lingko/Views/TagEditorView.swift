//
//  TagEditorView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData

struct TagEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)])
    private var allTags: [Tag]

    @State private var tagService = TagService()

    let translation: SavedTranslation

    @State private var selectedTagIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Translation preview
                VStack(alignment: .leading, spacing: 8) {
                    Text(translation.sourceText)
                        .font(.headline)
                        .lineLimit(3)
                        .foregroundStyle(.primary)

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
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))

                Divider()

                // Tag selection
                if allTags.isEmpty {
                    ContentUnavailableView {
                        Label("No Tags Available", systemImage: "tag.slash")
                    } description: {
                        Text("Create tags in Tag Management to organize your translations")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(allTags) { tag in
                                TagSelectionRow(
                                    tag: tag,
                                    isSelected: selectedTagIDs.contains(tag.id)
                                ) {
                                    toggleTag(tag)
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentTags()
            }
        }
    }

    private func loadCurrentTags() {
        if let tags = translation.tags {
            selectedTagIDs = Set(tags.map { $0.id })
        }
    }

    private func toggleTag(_ tag: Tag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
    }

    private func saveChanges() {
        let selectedTags = allTags.filter { selectedTagIDs.contains($0.id) }
        tagService.setTags(selectedTags, for: translation, context: modelContext)
    }
}

// MARK: - Tag Selection Row

private struct TagSelectionRow: View {
    let tag: Tag
    let isSelected: Bool
    let action: () -> Void

    var chipColor: Color {
        if let hex = tag.color {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Tag icon and name
                HStack(spacing: 8) {
                    Image(systemName: tag.icon)
                        .font(.title3)
                        .foregroundStyle(chipColor)
                        .frame(width: 32, height: 32)
                        .background(chipColor.opacity(0.15))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tag.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundStyle(.primary)

                        if tag.isSystem {
                            Text("System Tag")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }

                // Checkmark
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(chipColor)
                } else {
                    Image(systemName: "circle")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? chipColor.opacity(0.1) : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? chipColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: SavedTranslation.self, Tag.self,
        configurations: config
    )

    let translation = SavedTranslation(
        timestamp: Date(),
        sourceText: "Hello world",
        sourceLanguageCode: "en",
        detectionConfidence: 0.99,
        isFavorite: false,
        translations: "[]"
    )
    container.mainContext.insert(translation)

    return TagEditorView(translation: translation)
        .modelContainer(container)
}
