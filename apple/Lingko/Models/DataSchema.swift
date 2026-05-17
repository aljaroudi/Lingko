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
typealias Tag = DataSchema.Tag
typealias TranslationEntry = DataSchema.TranslationEntry

// MARK: - V1 Schema (Current)

enum DataSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] { [
         self.SavedTranslation.self,
         self.Tag.self,
    ] }

    static let versionIdentifier = Schema.Version(1, 0, 0)

    @Model
    final class SavedTranslation {
        var id: UUID
        var timestamp: Date
        var sourceText: String
        var sourceLanguageCode: String?
        var detectionConfidence: Double
        var isFavorite: Bool
        var translations: String
        @Relationship(deleteRule: .nullify, inverse: \Tag.translations)
        var tags: [Tag]?

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

        var sourceLanguageName: String {
            guard let code = sourceLanguageCode else { return "Unknown" }
            return Locale.current.localizedString(forLanguageCode: code) ?? code
        }

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

        var translationCount: Int {
            decodedTranslations?.count ?? 0
        }
    }

    @Model
    final class Tag {
        var id: UUID
        var name: String
        var icon: String
        var color: String?
        var isSystem: Bool
        var sortOrder: Int

        @Relationship(deleteRule: .nullify)
        var translations: [SavedTranslation]?

        init(
            id: UUID = UUID(),
            name: String,
            icon: String = "tag",
            color: String? = nil,
            isSystem: Bool = false,
            sortOrder: Int = 0
        ) {
            self.id = id
            self.name = name
            self.icon = icon
            self.color = color
            self.isSystem = isSystem
            self.sortOrder = sortOrder
        }

        var translationCount: Int {
            translations?.count ?? 0
        }
    }

    /// Represents a single translation to a target language
    struct TranslationEntry: Codable {
        let languageCode: String
        let text: String
        let romanization: String?
        let sentiment: Double?
        let entities: String?

        var languageName: String {
            Locale.current.localizedString(forLanguageCode: languageCode) ?? languageCode
        }
    }
}
