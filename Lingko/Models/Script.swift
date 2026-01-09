//
//  Script.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

/// Writing systems/scripts used by different languages
enum Script: String, Sendable {
    case latin = "Latin"
    case chinese = "Chinese"
    case japanese = "Japanese"
    case korean = "Korean"
    case arabic = "Arabic"
    case cyrillic = "Cyrillic"
    case devanagari = "Devanagari"
    case thai = "Thai"
    case hebrew = "Hebrew"
    case greek = "Greek"

    /// Whether this script needs romanization for Latin-alphabet readers
    var needsRomanization: Bool {
        self != .latin
    }

    /// Whether this script is written right-to-left
    var isRTL: Bool {
        self == .arabic || self == .hebrew
    }

    /// Detect script from language identifier
    static func detect(from language: Locale.Language) -> Script {
        let identifier = language.minimalIdentifier.lowercased()

        switch identifier {
        // Chinese variants
        case let id where id.hasPrefix("zh"):
            return .chinese

        // Japanese
        case "ja":
            return .japanese

        // Korean
        case "ko":
            return .korean

        // Arabic
        case let id where id.hasPrefix("ar"):
            return .arabic

        // Cyrillic-based languages
        case "ru", "uk", "be", "bg", "sr", "mk":
            return .cyrillic

        // Devanagari (Hindi, Sanskrit, etc.)
        case "hi", "sa", "mr", "ne":
            return .devanagari

        // Thai
        case "th":
            return .thai

        // Hebrew
        case "he", "iw":
            return .hebrew

        // Greek
        case "el":
            return .greek

        // Default to Latin for European and other languages
        default:
            return .latin
        }
    }
}
