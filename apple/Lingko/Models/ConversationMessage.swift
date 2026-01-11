//
//  ConversationMessage.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

/// Represents a single message in a conversation session
struct ConversationMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let text: String
    let translation: String
    let fromLanguageCode: String
    let toLanguageCode: String
    let isFromLanguageA: Bool  // true if from Language A, false if from Language B

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        text: String,
        translation: String,
        fromLanguageCode: String,
        toLanguageCode: String,
        isFromLanguageA: Bool
    ) {
        self.id = id
        self.timestamp = timestamp
        self.text = text
        self.translation = translation
        self.fromLanguageCode = fromLanguageCode
        self.toLanguageCode = toLanguageCode
        self.isFromLanguageA = isFromLanguageA
    }

    var fromLanguageName: String {
        Locale.current.localizedString(forLanguageCode: fromLanguageCode) ?? fromLanguageCode
    }

    var toLanguageName: String {
        Locale.current.localizedString(forLanguageCode: toLanguageCode) ?? toLanguageCode
    }
}
