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

    /// Check if user has saved language preferences before
    static func hasSavedPreferences() -> Bool {
        return UserDefaults.standard.array(forKey: selectedLanguagesKey) != nil
    }

    /// Load selected languages from UserDefaults
    /// Note: This only validates against the supported language list, not actual installation status.
    /// Call sites should further validate that languages are still installed on the device.
    static func loadSelectedLanguages() -> Set<Locale.Language> {
        guard let languageCodes = UserDefaults.standard.array(forKey: selectedLanguagesKey) as? [String] else {
            // Return empty set - will be populated with downloaded languages on first launch
            return []
        }

        // Validate codes against supported list (now with fuzzy matching for code variations)
        let validLanguages = SupportedLanguages.validate(codes: languageCodes)

        // Return validated languages (even if below minimum - will be handled in UI)
        return Set(validLanguages)
    }

    /// Check if removing a language would violate minimum requirement
    static func canRemoveLanguage(from languages: Set<Locale.Language>) -> Bool {
        return languages.count > minimumLanguageCount
    }
}

