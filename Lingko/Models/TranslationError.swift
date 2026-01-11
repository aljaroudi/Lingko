//
//  TranslationError.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

enum TranslationError: LocalizedError {
    case languageNotSupported(String)
    case translationFailed(underlying: Error)
    case emptyInput
    case sessionCreationFailed
    case detectionFailed
    case invalidConfiguration
    case missingLanguagePacks([String])

    var errorDescription: String? {
        switch self {
        case .languageNotSupported(let language):
            return "Translation to \(language) is not supported"
        case .translationFailed(let error):
            return "Translation failed: \(error.localizedDescription)"
        case .emptyInput:
            return "Please enter text to translate"
        case .sessionCreationFailed:
            return "Failed to create translation session"
        case .detectionFailed:
            return "Failed to detect language"
        case .invalidConfiguration:
            return "Invalid translation configuration"
        case .missingLanguagePacks(let languages):
            if languages.count == 1 {
                return "\(languages[0]) is missing"
            } else if languages.count == 2 {
                return "\(languages[0]) and \(languages[1]) are missing"
            } else {
                let first = languages.dropLast().joined(separator: ", ")
                let last = languages.last!
                return "\(first), and \(last) are missing"
            }
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .languageNotSupported:
            return "Try selecting a different target language"
        case .translationFailed:
            return "Please try again"
        case .emptyInput:
            return "Enter some text in the input field"
        case .sessionCreationFailed:
            return "Check your internet connection and try again"
        case .detectionFailed:
            return "Try entering more text or specify the source language manually"
        case .invalidConfiguration:
            return "Please check your language selection"
        case .missingLanguagePacks:
            return "Download the language pack to continue"
        }
    }
}
