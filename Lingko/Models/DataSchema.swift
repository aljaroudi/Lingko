//
//  DataSchema.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import SwiftData

typealias DataSchema = DataSchemaV1
typealias SavedTranslation = DataSchema.SavedTranslation

enum DataSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] { [
         self.SavedTranslation.self,
    ] }

    static let versionIdentifier = Schema.Version(1, 0, 0)

    /// SavedTranslation model for persisting grouped translation history (Phase 4)
    /// Groups multiple target language translations for a single source text
    @Model
    final class SavedTranslation {
        var id: UUID
        var timestamp: Date
        var sourceText: String
        var sourceLanguageCode: String?
        var detectionConfidence: Double
        var isFavorite: Bool

        /// JSON-encoded array of translations to different target languages
        /// Format: [{"languageCode": "es", "text": "Hola", "romanization": null, "sentiment": 0.5, "entities": "[...]"}]
        var translations: String

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            sourceText: String,
            sourceLanguageCode: String?,
            detectionConfidence: Double,
            isFavorite: Bool = false,
            translations: String
        ) {
            self.id = id
            self.timestamp = timestamp
            self.sourceText = sourceText
            self.sourceLanguageCode = sourceLanguageCode
            self.detectionConfidence = detectionConfidence
            self.isFavorite = isFavorite
            self.translations = translations
        }

        // MARK: - Computed Properties

        /// Human-readable source language name
        var sourceLanguageName: String {
            guard let code = sourceLanguageCode else { return "Unknown" }
            return Locale.current.localizedString(forLanguageCode: code) ?? code
        }

        /// Confidence as percentage string
        var confidencePercentage: String {
            String(format: "%.0f%%", detectionConfidence * 100)
        }

        /// Decoded translations array
        var decodedTranslations: [TranslationEntry]? {
            guard let data = translations.data(using: .utf8),
                  let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                return nil
            }

            return array.compactMap { dict in
                guard let languageCode = dict["languageCode"] as? String,
                      let text = dict["text"] as? String else {
                    return nil
                }
                return TranslationEntry(
                    languageCode: languageCode,
                    text: text,
                    romanization: dict["romanization"] as? String,
                    sentiment: dict["sentiment"] as? Double,
                    entities: dict["entities"] as? String
                )
            }
        }

        /// Number of target languages translated to
        var translationCount: Int {
            decodedTranslations?.count ?? 0
        }

        /// Comma-separated list of target language names
        var targetLanguagesDescription: String {
            guard let translations = decodedTranslations else { return "" }
            let names = translations.map { translation in
                Locale.current.localizedString(forLanguageCode: translation.languageCode) ?? translation.languageCode
            }
            return names.joined(separator: ", ")
        }
    }

    /// Represents a single translation to a target language
    struct TranslationEntry: Codable {
        let languageCode: String
        let text: String
        let romanization: String?
        let sentiment: Double?
        let entities: String?  // JSON-encoded entities

        var languageName: String {
            Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
        }

        var sentimentDescription: String? {
            guard let sentiment else { return nil }
            if sentiment > 0.3 { return "Positive" }
            if sentiment < -0.3 { return "Negative" }
            return "Neutral"
        }
    }
}
