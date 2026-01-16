//
//  SupportedLanguages.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

/// Helper for managing supported translation languages
/// Provides a curated list to avoid duplicates and regional variants
struct SupportedLanguages {
    /// Curated list of supported languages (one variant per language)
    /// These are the most commonly used variants
    static let all: [LanguageInfo] = [
        // Major languages
        LanguageInfo(code: "ar", name: "Arabic"),
        LanguageInfo(code: "zh-Hans", name: "Chinese (Simplified)"),
        LanguageInfo(code: "zh-Hant", name: "Chinese (Traditional)"),
        LanguageInfo(code: "nl", name: "Dutch"),
        LanguageInfo(code: "en", name: "English"),
        LanguageInfo(code: "fr", name: "French"),
        LanguageInfo(code: "de", name: "German"),
        LanguageInfo(code: "hi", name: "Hindi"),
        LanguageInfo(code: "id", name: "Indonesian"),
        LanguageInfo(code: "it", name: "Italian"),
        LanguageInfo(code: "ja", name: "Japanese"),
        LanguageInfo(code: "ko", name: "Korean"),
        LanguageInfo(code: "pl", name: "Polish"),
        LanguageInfo(code: "pt-BR", name: "Portuguese (Brazil)"),
        LanguageInfo(code: "ru", name: "Russian"),
        LanguageInfo(code: "es", name: "Spanish"),
        LanguageInfo(code: "th", name: "Thai"),
        LanguageInfo(code: "tr", name: "Turkish"),
        LanguageInfo(code: "uk", name: "Ukrainian"),
        LanguageInfo(code: "vi", name: "Vietnamese"),

        // Additional European languages
        LanguageInfo(code: "cs", name: "Czech"),
        LanguageInfo(code: "da", name: "Danish"),
        LanguageInfo(code: "fi", name: "Finnish"),
        LanguageInfo(code: "el", name: "Greek"),
        LanguageInfo(code: "he", name: "Hebrew"),
        LanguageInfo(code: "hu", name: "Hungarian"),
        LanguageInfo(code: "no", name: "Norwegian"),
        LanguageInfo(code: "ro", name: "Romanian"),
        LanguageInfo(code: "sv", name: "Swedish"),

        // Additional Asian languages
        LanguageInfo(code: "bn", name: "Bengali"),
        LanguageInfo(code: "ms", name: "Malay"),
        LanguageInfo(code: "ta", name: "Tamil"),
        LanguageInfo(code: "te", name: "Telugu"),
    ]

    /// Get all supported languages as Locale.Language objects
    static var allLanguages: [Locale.Language] {
        all.map { $0.language }
    }

    /// Get device's current language if it's in our supported list
    static var deviceLanguage: Locale.Language? {
        let deviceCode = Locale.current.language.languageCode?.identifier ?? ""

        // Try exact match first
        if let match = all.first(where: { $0.code == deviceCode }) {
            return match.language
        }

        // Try matching just the base language code (e.g., "en" from "en-US")
        let baseCode = deviceCode.components(separatedBy: "-").first ?? deviceCode
        if let match = all.first(where: { $0.code.hasPrefix(baseCode) }) {
            return match.language
        }

        return nil
    }

    /// Get display name for a language
    static func displayName(for language: Locale.Language) -> String {
        if let info = all.first(where: { $0.language.minimalIdentifier == language.minimalIdentifier }) {
            return info.name
        }
        // Fallback to localized name
        return Locale.current.localizedString(forLanguageCode: language.minimalIdentifier)
            ?? language.minimalIdentifier
    }

    /// Normalize a language code by extracting the base language
    /// Examples: "en-US" → "en", "zh-Hans" → "zh-Hans" (kept as is), "zh" → "zh"
    static func normalizeCode(_ code: String) -> String {
        // For codes we explicitly define (like zh-Hans, zh-Hant, pt-BR), keep them as is
        if all.contains(where: { $0.code == code }) {
            return code
        }

        // Extract base language code (e.g., "en" from "en-US")
        let components = code.components(separatedBy: "-")
        return components.first ?? code
    }

    /// Find a matching language for a given code, handling variations
    /// Tries exact match first, then normalized match, then base language match
    static func findMatchingLanguage(for code: String) -> Locale.Language? {
        // Try exact match first
        if let match = all.first(where: { $0.code == code }) {
            return match.language
        }

        // Try normalized code
        let normalized = normalizeCode(code)
        if let match = all.first(where: { $0.code == normalized }) {
            return match.language
        }

        // Try base language match (e.g., "zh" matches "zh-Hans" or "zh-Hant")
        let baseCode = code.components(separatedBy: "-").first ?? code
        if let match = all.first(where: { $0.code.hasPrefix(baseCode) || $0.code == baseCode }) {
            return match.language
        }

        return nil
    }

    /// Validate a set of language codes and return valid languages
    /// Now uses fuzzy matching to handle language code variations
    static func validate(codes: [String]) -> [Locale.Language] {
        codes.compactMap { code in
            findMatchingLanguage(for: code)
        }
    }
}

/// Information about a supported language
struct LanguageInfo: Identifiable {
    let code: String
    let name: String

    var id: String { code }

    var language: Locale.Language {
        Locale.Language(identifier: code)
    }
}
