//
//  TagManagementView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: [SortDescriptor(\Tag.sortOrder), SortDescriptor(\Tag.name)])
    private var allTags: [Tag]

    @State private var tagService = TagService()
    @State private var showCreateTag = false
    @State private var showDeleteAlert = false
    @State private var tagToDelete: Tag?

    var body: some View {
        NavigationStack {
            Group {
                if allTags.isEmpty {
                    emptyStateView
                } else {
                    tagList
                }
            }
            .navigationTitle("Manage Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTag = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateTag) {
                CreateTagView()
            }
            .alert("Delete Tag", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {
                    tagToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    if let tag = tagToDelete {
                        tagService.deleteTag(tag, context: modelContext)
                        tagToDelete = nil
                    }
                }
            } message: {
                if let tag = tagToDelete {
                    Text("Are you sure you want to delete '\(tag.name)'? This will remove the tag from all translations.")
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Tags", systemImage: "tag.slash")
        } description: {
            Text("Create tags to organize your translation history")
        } actions: {
            Button {
                showCreateTag = true
            } label: {
                Label("Create Tag", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var tagList: some View {
        List {
            Section {
                ForEach(allTags) { tag in
                    TagManagementRow(
                        tag: tag,
                        onDelete: {
                            if !tag.isSystem {
                                tagToDelete = tag
                                showDeleteAlert = true
                            }
                        }
                    )
                }
            } header: {
                HStack {
                    Text("All Tags")
                    Spacer()
                    Text("\(allTags.count)")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("System tags cannot be deleted. Tags can be created automatically by AI or manually.")
                    .font(.caption)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Tag Management Row

private struct TagManagementRow: View {
    let tag: Tag
    let onDelete: () -> Void

    var chipColor: Color {
        if let hex = tag.color {
            return Color(hex: hex) ?? .blue
        }
        return .blue
    }

    var body: some View {
        HStack(spacing: 12) {
            // Tag icon
            Image(systemName: tag.icon)
                .font(.title3)
                .foregroundStyle(chipColor)
                .frame(width: 40, height: 40)
                .background(chipColor.opacity(0.15))
                .clipShape(Circle())

            // Tag details
            VStack(alignment: .leading, spacing: 4) {
                Text(tag.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 12) {
                    if tag.isSystem {
                        Label("System", systemImage: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let translationCount = tag.translations?.count, translationCount > 0 {
                        Label("\(translationCount)", systemImage: "doc.text")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Delete button (only for non-system tags)
            if !tag.isSystem {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Tag View

private struct CreateTagView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var tagService = TagService()
    @State private var name = ""
    @State private var selectedIcon = "tag"
    @State private var selectedColor: String?

    private let availableIcons = [
        "tag", "tag.fill", "star", "star.fill", "heart", "heart.fill",
        "bookmark", "bookmark.fill", "flag", "flag.fill", "folder", "folder.fill",
        "book", "book.fill", "paperplane", "paperplane.fill", "globe", "briefcase",
        "cart", "cart.fill", "house", "house.fill", "person", "person.fill"
    ]

    private let availableColors = [
        ("Red", "FF3B30"),
        ("Orange", "FF9500"),
        ("Yellow", "FFCC00"),
        ("Green", "34C759"),
        ("Mint", "00C7BE"),
        ("Teal", "30B0C7"),
        ("Cyan", "32ADE6"),
        ("Blue", "007AFF"),
        ("Indigo", "5856D6"),
        ("Purple", "AF52DE"),
        ("Pink", "FF2D55"),
        ("Brown", "A2845E"),
        ("Gray", "8E8E93")
    ]

    var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag Name") {
                    TextField("Enter tag name", text: $name)
                        .autocorrectionDisabled()
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .frame(width: 60, height: 60)
                                    .background(
                                        selectedIcon == icon
                                            ? Color.blue.opacity(0.2)
                                            : Color(.secondarySystemGroupedBackground)
                                    )
                                    .foregroundStyle(selectedIcon == icon ? .blue : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 12) {
                        ForEach(availableColors, id: \.1) { colorName, colorHex in
                            Button {
                                selectedColor = colorHex
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: colorHex) ?? .blue)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(
                                                    selectedColor == colorHex ? Color.primary : Color.clear,
                                                    lineWidth: 3
                                                )
                                        )

                                    Text(colorName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: selectedIcon)
                            .font(.title2)
                            .foregroundStyle(Color(hex: selectedColor ?? "007AFF") ?? .blue)
                            .frame(width: 50, height: 50)
                            .background(Color(hex: selectedColor ?? "007AFF")?.opacity(0.15) ?? Color.blue.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name.isEmpty ? "Tag Name" : name)
                                .font(.headline)
                            Text("Preview")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                } header: {
                    Text("Preview")
                }
            }
            .navigationTitle("Create Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTag()
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
    }

    private func createTag() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tagService.createTag(
            name: trimmedName,
            icon: selectedIcon,
            color: selectedColor,
            isSystem: false,
            context: modelContext
        )
    }
}

#Preview {
    TagManagementView()
        .modelContainer(for: Tag.self, inMemory: true)
}
