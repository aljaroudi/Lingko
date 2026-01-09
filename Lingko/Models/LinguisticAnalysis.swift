//
//  LinguisticAnalysis.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import NaturalLanguage
import SwiftUI

/// Comprehensive linguistic analysis of text
struct LinguisticAnalysis: Sendable {
    let sentiment: Double?              // -1.0 (negative) to 1.0 (positive)
    let entities: [NamedEntity]         // Named entities (people, places, orgs)
    let tokens: [LinguisticToken]       // Word-level analysis with POS tags
    let dominantLanguage: NLLanguage?
    let languageConfidence: Double

    init(
        sentiment: Double? = nil,
        entities: [NamedEntity] = [],
        tokens: [LinguisticToken] = [],
        dominantLanguage: NLLanguage? = nil,
        languageConfidence: Double = 0.0
    ) {
        self.sentiment = sentiment
        self.entities = entities
        self.tokens = tokens
        self.dominantLanguage = dominantLanguage
        self.languageConfidence = languageConfidence
    }

    /// Human-readable sentiment description
    var sentimentDescription: String {
        guard let sentiment else { return "Neutral" }

        switch sentiment {
        case 0.3...1.0:
            return "Positive"
        case -1.0..<(-0.3):
            return "Negative"
        default:
            return "Neutral"
        }
    }

    /// SF Symbol icon for sentiment
    var sentimentIcon: String {
        guard let sentiment else { return "minus.circle" }

        switch sentiment {
        case 0.3...1.0:
            return "face.smiling"
        case -1.0..<(-0.3):
            return "face.frowning"
        default:
            return "minus.circle"
        }
    }

    /// Color for sentiment visualization
    var sentimentColor: Color {
        guard let sentiment else { return .gray }

        switch sentiment {
        case 0.3...1.0:
            return .green
        case -1.0..<(-0.3):
            return .red
        default:
            return .gray
        }
    }

    /// Formatted sentiment score
    var sentimentScore: String {
        guard let sentiment else { return "N/A" }
        return String(format: "%.2f", sentiment)
    }

    /// Check if analysis contains meaningful data
    var hasData: Bool {
        sentiment != nil || !entities.isEmpty || !tokens.isEmpty
    }
}
