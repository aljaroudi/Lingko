//
//  TranslationResult.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

struct TranslationResult: Identifiable, Sendable {
    let id: UUID
    let language: Locale.Language
    let sourceLanguage: Locale.Language?
    let translation: String
    let detectionConfidence: Double
    let timestamp: Date

    init(
        id: UUID = UUID(),
        language: Locale.Language,
        sourceLanguage: Locale.Language?,
        translation: String,
        detectionConfidence: Double,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.language = language
        self.sourceLanguage = sourceLanguage
        self.translation = translation
        self.detectionConfidence = detectionConfidence
        self.timestamp = timestamp
    }

    /// Human-readable language name
    var languageName: String {
        Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
    }

    /// Whether this result is for the source language (echo)
    var isSourceLanguage: Bool {
        guard let sourceLanguage else { return false }
        return language == sourceLanguage
    }

    /// Confidence level as percentage string
    var confidencePercentage: String {
        String(format: "%.0f%%", detectionConfidence * 100)
    }
}
