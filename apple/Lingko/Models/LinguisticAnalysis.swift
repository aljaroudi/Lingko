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
    let entities: [NamedEntity]         // Named entities (people, places, orgs)
    let tokens: [LinguisticToken]       // Word-level analysis with POS tags
    let dominantLanguage: NLLanguage?
    let languageConfidence: Double

    init(
        entities: [NamedEntity] = [],
        tokens: [LinguisticToken] = [],
        dominantLanguage: NLLanguage? = nil,
        languageConfidence: Double = 0.0
    ) {
        self.entities = entities
        self.tokens = tokens
        self.dominantLanguage = dominantLanguage
        self.languageConfidence = languageConfidence
    }

    /// Check if analysis contains meaningful data
    var hasData: Bool {
        !entities.isEmpty || !tokens.isEmpty
    }
}
