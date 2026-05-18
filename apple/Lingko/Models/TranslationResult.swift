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

    // Linguistic analysis
    var linguisticAnalysis: LinguisticAnalysis?
    var formalityLevel: FormalityLevel? // Formal/informal/neutral

    init(
        id: UUID = UUID(),
        language: Locale.Language,
        sourceLanguage: Locale.Language?,
        translation: String,
        detectionConfidence: Double,
        timestamp: Date = Date(),
        romanization: String? = nil,
        sourceRomanization: String? = nil,
        linguisticAnalysis: LinguisticAnalysis? = nil,
        formalityLevel: FormalityLevel? = nil
    ) {
        self.id = id
        self.language = language
        self.sourceLanguage = sourceLanguage
        self.translation = translation
        self.detectionConfidence = detectionConfidence
        self.timestamp = timestamp
        self.romanization = romanization
        self.sourceRomanization = sourceRomanization
        self.linguisticAnalysis = linguisticAnalysis
        self.formalityLevel = formalityLevel
    }

    /// Human-readable language name
    var languageName: String {
        Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
    }

    /// The layout direction for this language (RTL for Arabic/Hebrew, LTR otherwise)
    var layoutDirection: LayoutDirection {
        let script = Script.detect(from: language)
        return script.isRTL ? .rightToLeft : .leftToRight
    }
}
