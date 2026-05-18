//
//  SupportedLanguages.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation

extension Notification.Name {
    static let supportedLanguagesDidChange = Notification.Name("supportedLanguagesDidChange")
}

/// Helper for managing translation language display and storage.
struct SupportedLanguages {
    /// Get display name for a language
    static func displayName(for language: Locale.Language) -> String {
        displayName(for: language, code: code(for: language))
    }

    static func languageInfo(for language: Locale.Language) -> LanguageInfo {
        LanguageInfo(
            code: code(for: language),
            name: displayName(for: language),
            language: language
        )
    }

    static func languageInfos(for languages: [Locale.Language]) -> [LanguageInfo] {
        var seenCodes: Set<String> = []

        return languages.compactMap { language in
            let code = code(for: language)
            guard seenCodes.insert(code).inserted else { return nil }

            return LanguageInfo(
                code: code,
                name: displayName(for: language, code: code),
                language: language
            )
        }
        .sorted {
            $0.code.localizedCaseInsensitiveCompare($1.code) == .orderedAscending
        }
    }

    static func disabledLanguageCodeSet(from storageValue: String) -> Set<String> {
        Set(storageValue.split(separator: "\n").map(String.init))
    }

    static func storageValue(forDisabledLanguageCodes codes: Set<String>) -> String {
        codes.sorted().joined(separator: "\n")
    }

    static func code(for language: Locale.Language) -> String {
        code(for: language, needsDisambiguation: true)
    }

    static func isEnabled(_ language: Locale.Language, disabledLanguageCodes: Set<String>) -> Bool {
        !disabledLanguageCodes.contains(code(for: language))
    }

    static func enabledLanguages(
        from installedLanguages: Set<Locale.Language>,
        disabledLanguageCodes storageValue: String
    ) -> Set<Locale.Language> {
        let disabledCodes = disabledLanguageCodeSet(from: storageValue)
        return installedLanguages.filter { isEnabled($0, disabledLanguageCodes: disabledCodes) }
    }

    static func installedLanguageInfos(for installedLanguages: Set<Locale.Language>) -> [LanguageInfo] {
        languageInfos(for: Array(installedLanguages))
    }

    private static func displayName(for language: Locale.Language, code: String) -> String {
        let name = Locale.current.localizedString(forLanguageCode: baseCode(for: language))
            ?? Locale.current.localizedString(forIdentifier: code)
            ?? code

        guard let region = language.region?.identifier,
              let flag = flagEmoji(forRegion: region) else {
            return name
        }

        return "\(flag) \(name)"
    }

    private static func code(for language: Locale.Language, needsDisambiguation: Bool) -> String {
        let base = baseCode(for: language)

        guard needsDisambiguation else {
            return base
        }

        var parts = [base]
        if base == "zh", let script = language.script?.identifier {
            parts.append(script)
            return parts.joined(separator: "-")
        }
        if let region = language.region?.identifier {
            parts.append(region)
        }

        return parts.joined(separator: "-")
    }

    private static func baseCode(for language: Locale.Language) -> String {
        language.languageCode?.identifier ?? language.minimalIdentifier
    }

    private static func flagEmoji(forRegion region: String) -> String? {
        let scalars = Array(region.uppercased().unicodeScalars)
        guard scalars.count == 2,
              scalars.allSatisfy({ (65...90).contains($0.value) }) else {
            return nil
        }

        return String(String.UnicodeScalarView(scalars.compactMap {
            UnicodeScalar(127397 + $0.value)
        }))
    }
}

/// Information about a supported language
struct LanguageInfo: Identifiable, Equatable {
    let code: String
    let name: String
    let language: Locale.Language

    var id: String { code }

    init(code: String, name: String, language: Locale.Language? = nil) {
        self.code = code
        self.name = name
        self.language = language ?? Locale.Language(identifier: code)
    }
}
