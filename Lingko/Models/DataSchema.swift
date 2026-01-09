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

    /// SavedTranslation model for persisting translation history (Phase 5)
    @Model
    final class SavedTranslation {
        var id: UUID
        var timestamp: Date
        var sourceText: String
        var sourceLanguageCode: String?
        var targetLanguageCode: String
        var translatedText: String
        var detectionConfidence: Double
        var isFavorite: Bool

        init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            sourceText: String,
            sourceLanguageCode: String?,
            targetLanguageCode: String,
            translatedText: String,
            detectionConfidence: Double,
            isFavorite: Bool = false
        ) {
            self.id = id
            self.timestamp = timestamp
            self.sourceText = sourceText
            self.sourceLanguageCode = sourceLanguageCode
            self.targetLanguageCode = targetLanguageCode
            self.translatedText = translatedText
            self.detectionConfidence = detectionConfidence
            self.isFavorite = isFavorite
        }
    }
}
