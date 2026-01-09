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

    /// Save multiple translation results as a grouped translation session
    func saveTranslations(
        _ results: [TranslationResult],
        sourceText: String,
        context: ModelContext
    ) {
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

        do {
            try context.save()
            logger.info("💾 Saved grouped translation: \(sourceText.prefix(30))... → \(results.count) languages")
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
