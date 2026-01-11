//
//  RomanizationSystem.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

/// Romanization systems for converting non-Latin scripts to Latin alphabet
enum RomanizationSystem: String, CaseIterable, Sendable {
    // Chinese
    case pinyinWithTones = "Pinyin (with tones)"
    case pinyinWithoutTones = "Pinyin (no tones)"

    // Japanese
    case romajiHepburn = "Romaji (Hepburn)"

    // Korean
    case koreanRevised = "Revised Romanization"

    // Arabic
    case arabicALALC = "ALA-LC"

    // Generic Latin conversion for any script
    case latinAny = "Latin (any script)"

    /// The CFStringTransform identifier for this romanization system
    var transformID: CFString {
        switch self {
        case .pinyinWithTones, .pinyinWithoutTones:
            return kCFStringTransformMandarinLatin
        case .romajiHepburn, .koreanRevised, .arabicALALC, .latinAny:
            return kCFStringTransformToLatin
        }
    }

    /// Whether to strip diacritical marks (tone marks, accents)
    var stripDiacritics: Bool {
        switch self {
        case .pinyinWithoutTones:
            return true
        default:
            return false
        }
    }

    /// Get available romanization systems for a specific language
    static func systems(for language: Locale.Language) -> [RomanizationSystem] {
        let identifier = language.minimalIdentifier.lowercased()

        switch identifier {
        case "zh", "zh-hans", "zh-hant", "cmn":
            return [.pinyinWithTones, .pinyinWithoutTones]
        case "ja":
            return [.romajiHepburn]
        case "ko":
            return [.koreanRevised]
        case "ar":
            return [.arabicALALC]
        default:
            // For other non-Latin scripts, offer generic Latin conversion
            return [.latinAny]
        }
    }

    /// Get the default romanization system for a language
    static func defaultSystem(for language: Locale.Language) -> RomanizationSystem? {
        systems(for: language).first
    }
}
