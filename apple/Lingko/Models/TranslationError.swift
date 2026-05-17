//
//  TranslationError.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

enum TranslationError: LocalizedError {
    case detectionFailed
    case invalidConfiguration
    case missingLanguagePacks([String])

    var errorDescription: String? {
        switch self {
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
        case .detectionFailed:
            return "Try entering more text or specify the source language manually"
        case .invalidConfiguration:
            return "Please check your language selection"
        case .missingLanguagePacks:
            return "Download the language pack to continue"
        }
    }
}
