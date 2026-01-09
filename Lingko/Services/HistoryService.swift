//
//  HistoryService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import SwiftData
import OSLog
import NaturalLanguage

/// Stateless service for managing translation history persistence
@MainActor
struct HistoryService {
    private let logger = Logger(subsystem: "com.lingko.app", category: "HistoryService")

    // MARK: - Create

    /// Save multiple translation results as a grouped translation session with AI-powered tagging
    func saveTranslations(
        _ results: [TranslationResult],
        sourceText: String,
        context: ModelContext,
        aiService: AIAssistantService? = nil,
        tagService: TagService? = nil
    ) async {
        guard !results.isEmpty else { return }

        // Encode all translation results into JSON
        let translationEntries: [[String: Any?]] = results.map { result in
            [
                "languageCode": result.language.minimalIdentifier,
                "text": result.translation,
                "romanization": result.romanization,
                "sentiment": result.linguisticAnalysis?.sentiment,
                "entities": encodeEntities(result.linguisticAnalysis?.entities ?? [])
            ]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: translationEntries),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            logger.error("❌ Failed to encode translations to JSON")
            return
        }

        // Create single SavedTranslation entry with all translations
        let savedTranslation = SavedTranslation(
            timestamp: Date(),
            sourceText: sourceText,
            sourceLanguageCode: results.first?.sourceLanguage?.minimalIdentifier,
            detectionConfidence: results.first?.detectionConfidence ?? 0.0,
            isFavorite: false,
            translations: jsonString
        )

        context.insert(savedTranslation)

        // Apply AI-suggested tags if services provided
        if let aiService = aiService, let tagService = tagService {
            logger.info("🤖 Requesting AI tag suggestions...")
            let suggestedTagNames = await aiService.suggestTags(for: sourceText)

            if !suggestedTagNames.isEmpty {
                logger.info("🏷️ AI suggested tags: \(suggestedTagNames.joined(separator: ", "))")
                let tags = tagService.getOrCreateTags(byNames: suggestedTagNames, context: context)
                savedTranslation.tags = tags
            }
        }

        do {
            try context.save()
            let tagInfo = savedTranslation.tags?.map { $0.name }.joined(separator: ", ") ?? "none"
            logger.info("💾 Saved translation: \(sourceText.prefix(30))... → \(results.count) languages, tags: \(tagInfo)")
        } catch {
            logger.error("❌ Failed to save translations: \(error.localizedDescription)")
        }
    }

    // MARK: - Read

    /// Fetch translation history with optional limit
    func fetchHistory(limit: Int? = nil, context: ModelContext) -> [SavedTranslation] {
        let descriptor = FetchDescriptor<SavedTranslation>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            var results = try context.fetch(descriptor)

            if let limit {
                results = Array(results.prefix(limit))
            }

            logger.debug("📖 Fetched \(results.count) history entries")
            return results
        } catch {
            logger.error("❌ Failed to fetch history: \(error.localizedDescription)")
            return []
        }
    }

    /// Search history by source or translated text
    func searchHistory(query: String, context: ModelContext) -> [SavedTranslation] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return fetchHistory(context: context)
        }

        // Note: Predicate searches both sourceText and the translations JSON string
        // While not ideal for performance, it works for the scale of this app
        let predicate = #Predicate<SavedTranslation> { translation in
            translation.sourceText.localizedStandardContains(trimmedQuery) ||
            translation.translations.localizedStandardContains(trimmedQuery)
        }

        let descriptor = FetchDescriptor<SavedTranslation>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            logger.debug("🔍 Search '\(trimmedQuery)' returned \(results.count) results")
            return results
        } catch {
            logger.error("❌ Failed to search history: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch only favorite translations
    func fetchFavorites(context: ModelContext) -> [SavedTranslation] {
        let predicate = #Predicate<SavedTranslation> { translation in
            translation.isFavorite == true
        }

        let descriptor = FetchDescriptor<SavedTranslation>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let results = try context.fetch(descriptor)
            logger.debug("⭐ Fetched \(results.count) favorites")
            return results
        } catch {
            logger.error("❌ Failed to fetch favorites: \(error.localizedDescription)")
            return []
        }
    }

    /// Fetch history filtered by tags
    func fetchHistory(filteredBy tags: [Tag], context: ModelContext) -> [SavedTranslation] {
        guard !tags.isEmpty else {
            return fetchHistory(context: context)
        }

        logger.debug("🏷️ Fetching history filtered by \(tags.count) tags")

        let descriptor = FetchDescriptor<SavedTranslation>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let allHistory = try context.fetch(descriptor)
            let tagIDs = Set(tags.map { $0.id })

            // Filter translations that have ANY of the specified tags
            let filtered = allHistory.filter { translation in
                guard let translationTags = translation.tags else { return false }
                return translationTags.contains { tagIDs.contains($0.id) }
            }

            logger.debug("🏷️ Found \(filtered.count) translations with specified tags")
            return filtered
        } catch {
            logger.error("❌ Failed to fetch filtered history: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Update

    /// Toggle favorite status
    func toggleFavorite(_ translation: SavedTranslation, context: ModelContext) {
        translation.isFavorite.toggle()

        do {
            try context.save()
            let status = translation.isFavorite ? "⭐" : "☆"
            logger.info("\(status) Toggled favorite for: \(translation.sourceText.prefix(30))...")
        } catch {
            logger.error("❌ Failed to toggle favorite: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete

    /// Delete a single translation by reference
    func deleteTranslation(_ translation: SavedTranslation, context: ModelContext) {
        context.delete(translation)

        do {
            try context.save()
            logger.info("🗑️ Deleted translation: \(translation.sourceText.prefix(30))...")
        } catch {
            logger.error("❌ Failed to delete translation: \(error.localizedDescription)")
        }
    }

    /// Delete a translation by ID
    func deleteTranslation(byId id: UUID, context: ModelContext) {
        let predicate = #Predicate<SavedTranslation> { translation in
            translation.id == id
        }

        let descriptor = FetchDescriptor<SavedTranslation>(predicate: predicate)

        do {
            let results = try context.fetch(descriptor)
            if let translation = results.first {
                context.delete(translation)
                try context.save()
                logger.info("🗑️ Deleted translation by ID: \(id)")
            }
        } catch {
            logger.error("❌ Failed to delete translation by ID: \(error.localizedDescription)")
        }
    }

    /// Clear all history
    func clearAll(context: ModelContext) {
        let descriptor = FetchDescriptor<SavedTranslation>()

        do {
            let allTranslations = try context.fetch(descriptor)
            let count = allTranslations.count

            for translation in allTranslations {
                context.delete(translation)
            }

            try context.save()
            logger.warning("🗑️ Cleared all history (\(count) entries)")
        } catch {
            logger.error("❌ Failed to clear history: \(error.localizedDescription)")
        }
    }

    // MARK: - Helper Methods

    /// Encode named entities to JSON string
    private func encodeEntities(_ entities: [NamedEntity]) -> String? {
        guard !entities.isEmpty else { return nil }

        let simplifiedEntities = entities.map { entity in
            [
                "text": entity.text,
                "type": entity.type.rawValue
            ]
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: simplifiedEntities),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        return jsonString
    }

}
