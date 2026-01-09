//
//  LinguisticToken.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import NaturalLanguage
import SwiftUI

/// A word token with linguistic annotations (POS, lemma)
struct LinguisticToken: Identifiable, Sendable {
    let id: UUID
    let text: String
    let lemma: String?
    let partOfSpeech: NLTag?

    init(id: UUID = UUID(), text: String, lemma: String?, partOfSpeech: NLTag?) {
        self.id = id
        self.text = text
        self.lemma = lemma
        self.partOfSpeech = partOfSpeech
    }

    /// Human-readable part-of-speech description
    var posDescription: String {
        guard let pos = partOfSpeech else { return "Unknown" }

        switch pos {
        case .noun:
            return "Noun"
        case .verb:
            return "Verb"
        case .adjective:
            return "Adjective"
        case .adverb:
            return "Adverb"
        case .pronoun:
            return "Pronoun"
        case .determiner:
            return "Determiner"
        case .particle:
            return "Particle"
        case .preposition:
            return "Preposition"
        case .number:
            return "Number"
        case .conjunction:
            return "Conjunction"
        case .interjection:
            return "Interjection"
        case .classifier:
            return "Classifier"
        case .idiom:
            return "Idiom"
        default:
            return "Other"
        }
    }

    /// Color coding for part-of-speech visualization
    var color: Color {
        guard let pos = partOfSpeech else { return .gray }

        switch pos {
        case .noun:
            return .blue
        case .verb:
            return .green
        case .adjective:
            return .orange
        case .adverb:
            return .purple
        case .pronoun:
            return .pink
        case .determiner, .particle, .preposition:
            return .cyan
        case .number:
            return .red
        case .conjunction:
            return .yellow
        case .interjection:
            return .mint
        default:
            return .gray
        }
    }
}
