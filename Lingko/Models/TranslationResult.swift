//
//  TranslationResult.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import SwiftUI

struct TranslationResult: Identifiable, Sendable {
    let id: UUID
    let language: Locale.Language
    let sourceLanguage: Locale.Language?
    let translation: String
    let detectionConfidence: Double
    let timestamp: Date

    // Romanization
    var romanization: String?
    var sourceRomanization: String?
    var romanizationSystem: RomanizationSystem?

    // Linguistic analysis
    var linguisticAnalysis: LinguisticAnalysis?

    // AI-enhanced (optional)
    var alternatives: [Alternative]? // Other ways to say it
    var exampleSentences: [String]? // Usage examples
    var formalityLevel: FormalityLevel? // Formal/informal/neutral
    var culturalNotes: String? // Context about usage

    init(
        id: UUID = UUID(),
        language: Locale.Language,
        sourceLanguage: Locale.Language?,
        translation: String,
        detectionConfidence: Double,
        timestamp: Date = Date(),
        romanization: String? = nil,
        sourceRomanization: String? = nil,
        romanizationSystem: RomanizationSystem? = nil,
        linguisticAnalysis: LinguisticAnalysis? = nil,
        alternatives: [Alternative]? = nil,
        exampleSentences: [String]? = nil,
        formalityLevel: FormalityLevel? = nil,
        culturalNotes: String? = nil
    ) {
        self.id = id
        self.language = language
        self.sourceLanguage = sourceLanguage
        self.translation = translation
        self.detectionConfidence = detectionConfidence
        self.timestamp = timestamp
        self.romanization = romanization
        self.sourceRomanization = sourceRomanization
        self.romanizationSystem = romanizationSystem
        self.linguisticAnalysis = linguisticAnalysis
        self.alternatives = alternatives
        self.exampleSentences = exampleSentences
        self.formalityLevel = formalityLevel
        self.culturalNotes = culturalNotes
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

    /// Whether this language uses a non-Latin script and could benefit from romanization
    var needsRomanization: Bool {
        let script = Script.detect(from: language)
        return script.needsRomanization
    }

    /// The layout direction for this language (RTL for Arabic/Hebrew, LTR otherwise)
    var layoutDirection: LayoutDirection {
        let script = Script.detect(from: language)
        return script.isRTL ? .rightToLeft : .leftToRight
    }
}
