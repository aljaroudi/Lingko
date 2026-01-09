//
//  LanguagePreferences.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

/// Helper for persisting language selection preferences using UserDefaults
struct LanguagePreferences {
    private static let selectedLanguagesKey = "selectedLanguages"
    private static let minimumLanguageCount = 2

    /// Save selected languages to UserDefaults
    static func saveSelectedLanguages(_ languages: Set<Locale.Language>) {
        let languageCodes = languages.map { $0.minimalIdentifier }
        UserDefaults.standard.set(languageCodes, forKey: selectedLanguagesKey)
    }

    /// Load selected languages from UserDefaults
    static func loadSelectedLanguages() -> Set<Locale.Language> {
        guard let languageCodes = UserDefaults.standard.array(forKey: selectedLanguagesKey) as? [String] else {
            // Return default languages if none saved
            return defaultLanguages()
        }

        // Validate codes against supported list
        let validLanguages = SupportedLanguages.validate(codes: languageCodes)

        // Ensure minimum count
        if validLanguages.count >= minimumLanguageCount {
            return Set(validLanguages)
        } else {
            // Not enough valid languages, return defaults
            return defaultLanguages()
        }
    }

    /// Default languages when nothing is saved
    /// Includes device language if supported, plus popular languages
    static func defaultLanguages() -> Set<Locale.Language> {
        var defaults: Set<Locale.Language> = []

        // Add device language if supported
        if let deviceLang = SupportedLanguages.deviceLanguage {
            defaults.insert(deviceLang)
        }

        // Add common languages
        let commonLanguages = [
            Locale.Language(identifier: "es"), // Spanish
            Locale.Language(identifier: "fr"), // French
            Locale.Language(identifier: "de"), // German
            Locale.Language(identifier: "en")  // English
        ]

        for language in commonLanguages {
            defaults.insert(language)
            if defaults.count >= 3 {
                break
            }
        }

        return defaults
    }

    /// Check if removing a language would violate minimum requirement
    static func canRemoveLanguage(from languages: Set<Locale.Language>) -> Bool {
        return languages.count > minimumLanguageCount
    }
}

