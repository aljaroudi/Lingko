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
typealias GlossaryTerm = DataSchema.GlossaryTerm
typealias ConversationSession = DataSchema.ConversationSession

// MARK: - V1 Schema (Current)

enum DataSchemaV1: VersionedSchema {
    static var models: [any PersistentModel.Type] { [
         self.SavedTranslation.self,
         self.Tag.self,
         self.GlossaryTerm.self,
         self.ConversationSession.self,
    ] }

    static let versionIdentifier = Schema.Version(1, 0, 0)

    /// SavedTranslation model with tag support (Phase 6 - Enhanced History)
    @Model
    final class SavedTranslation {
        var id: UUID
        var timestamp: Date
        var sourceText: String
        var sourceLanguageCode: String?
        var detectionConfidence: Double
        var isFavorite: Bool

        /// JSON-encoded array of translations to different target languages
        var translations: String

        /// Tags (categories) applied to this translation
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

        // MARK: - Computed Properties

        var sourceLanguageName: String {
            guard let code = sourceLanguageCode else { return "Unknown" }
            return Locale.current.localizedString(forLanguageCode: code) ?? code
        }

        var confidencePercentage: String {
            String(format: "%.0f%%", detectionConfidence * 100)
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

        var targetLanguagesDescription: String {
            guard let translations = decodedTranslations else { return "" }
            let names = translations.map { translation in
                Locale.current.localizedString(forLanguageCode: translation.languageCode) ?? translation.languageCode
            }
            return names.joined(separator: ", ")
        }
    }

    /// Tag model for categorizing translations (Phase 6)
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

    /// GlossaryTerm model for custom terminology management (Phase 6)
    @Model
    final class GlossaryTerm {
        var id: UUID
        var timestamp: Date
        var term: String
        var definition: String?
        var domain: String
        var sourceLanguageCode: String
        var isFavorite: Bool

        /// JSON-encoded dictionary of translations: {"es": "término", "fr": "terme"}
        var translations: String

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            term: String,
            definition: String? = nil,
            domain: String = "General",
            sourceLanguageCode: String,
            isFavorite: Bool = false,
            translations: String
        ) {
            self.id = id
            self.timestamp = timestamp
            self.term = term
            self.definition = definition
            self.domain = domain
            self.sourceLanguageCode = sourceLanguageCode
            self.isFavorite = isFavorite
            self.translations = translations
        }
    }

    /// ConversationSession model for conversation mode (Phase 6)
    @Model
    final class ConversationSession {
        var id: UUID
        var timestamp: Date
        var title: String
        var languageAPairCode: String
        var languageBPairCode: String

        /// JSON-encoded array of messages
        var messages: String

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            title: String = "Conversation",
            languageAPairCode: String,
            languageBPairCode: String,
            messages: String = "[]"
        ) {
            self.id = id
            self.timestamp = timestamp
            self.title = title
            self.languageAPairCode = languageAPairCode
            self.languageBPairCode = languageBPairCode
            self.messages = messages
        }

        var languageAPairName: String {
            Locale.current.localizedString(forLanguageCode: languageAPairCode) ?? languageAPairCode
        }

        var languageBPairName: String {
            Locale.current.localizedString(forLanguageCode: languageBPairCode) ?? languageBPairCode
        }

        var conversationDescription: String {
            "\(languageAPairName) ↔ \(languageBPairName)"
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

        var sentimentDescription: String? {
            guard let sentiment else { return nil }
            if sentiment > 0.3 { return "Positive" }
            if sentiment < -0.3 { return "Negative" }
            return "Neutral"
        }
    }
}
