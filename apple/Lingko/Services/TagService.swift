//
//  TagService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import SwiftData
import OSLog

@MainActor
struct TagService {
    private let logger = Logger(subsystem: "com.lingko.tags", category: "service")

    // MARK: - Tags

    /// Fetch all tags, sorted by sort order
    func fetchTags(context: ModelContext) -> [Tag] {
        logger.debug("📚 Fetching tags")

        let descriptor = FetchDescriptor<Tag>(
            sortBy: [SortDescriptor(\.sortOrder), SortDescriptor(\.name)]
        )

        do {
            let tags = try context.fetch(descriptor)
            logger.info("✅ Fetched \(tags.count) tags")
            return tags
        } catch {
            logger.error("❌ Failed to fetch tags: \(error.localizedDescription)")
            return []
        }
    }

    /// Create a new tag
    func createTag(
        name: String,
        icon: String = "tag",
        color: String? = nil,
        sortOrder: Int? = nil,
        isSystem: Bool = false,
        context: ModelContext
    ) {
        logger.info("➕ Creating tag: \(name)")

        let order = sortOrder ?? (fetchTags(context: context).count + 1)
        let tag = Tag(
            name: name,
            icon: icon,
            color: color,
            isSystem: isSystem,
            sortOrder: order
        )

        context.insert(tag)

        do {
            try context.save()
            logger.info("✅ Tag created successfully")
        } catch {
            logger.error("❌ Failed to save tag: \(error.localizedDescription)")
        }
    }

    /// Delete a tag
    func deleteTag(_ tag: Tag, context: ModelContext) {
        logger.info("🗑️ Deleting tag: \(tag.name)")

        guard !tag.isSystem else {
            logger.warning("⚠️ Cannot delete system tag")
            return
        }

        context.delete(tag)

        do {
            try context.save()
            logger.info("✅ Tag deleted successfully")
        } catch {
            logger.error("❌ Failed to delete tag: \(error.localizedDescription)")
        }
    }

    /// Initialize default system tags if they don't exist
    func initializeDefaultTags(context: ModelContext) {
        logger.info("🏁 Initializing default tags")

        let existingTags = fetchTags(context: context)
        guard existingTags.isEmpty else {
            logger.debug("Tags already exist, skipping initialization")
            return
        }

        let defaultTags = [
            ("Greetings", "hand.wave.fill", "FF9500", 1),      // Orange
            ("Travel", "airplane", "007AFF", 2),                 // Blue
            ("Dining", "fork.knife", "FF2D55", 3),               // Red
            ("Shopping", "cart.fill", "AF52DE", 4),              // Purple
            ("Directions", "map.fill", "5AC8FA", 5),             // Light Blue
            ("Emergency", "exclamationmark.triangle.fill", "FF3B30", 6), // Red
            ("Numbers", "number", "34C759", 7),                  // Green
            ("Time & Date", "clock.fill", "FF9500", 8),          // Orange
            ("Weather", "cloud.sun.fill", "FFCC00", 9),          // Yellow
            ("General", "folder.fill", "8E8E93", 10)             // Gray
        ]

        for (name, icon, color, order) in defaultTags {
            createTag(name: name, icon: icon, color: color, sortOrder: order, isSystem: true, context: context)
        }

        logger.info("✅ Initialized \(defaultTags.count) default tags")
    }

    /// Set tags for a translation (replaces all existing tags)
    func setTags(_ tags: [Tag], for translation: SavedTranslation, context: ModelContext) {
        logger.info("🏷️ Setting \(tags.count) tags for translation")

        translation.tags = tags

        do {
            try context.save()
            logger.info("✅ Tags set successfully")
        } catch {
            logger.error("❌ Failed to set tags: \(error.localizedDescription)")
        }
    }

    /// Find tags by names (case-insensitive)
    func findTags(byNames names: [String], context: ModelContext) -> [Tag] {
        logger.debug("🔍 Finding tags by names: \(names.joined(separator: ", "))")

        let allTags = fetchTags(context: context)
        let lowercaseNames = Set(names.map { $0.lowercased() })

        let matchedTags = allTags.filter { tag in
            lowercaseNames.contains(tag.name.lowercased())
        }

        logger.info("✅ Found \(matchedTags.count) matching tags")
        return matchedTags
    }
}
