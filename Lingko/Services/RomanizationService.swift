//
//  RomanizationService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import OSLog

@MainActor
struct RomanizationService {
    private let logger = Logger(subsystem: "com.lingko.romanization", category: "service")

    // MARK: - Romanization

    /// Romanize text using the specified or default system for the language
    func romanize(
        text: String,
        language: Locale.Language,
        system: RomanizationSystem? = nil
    ) -> String? {
        guard !text.isEmpty else {
            logger.debug("Empty text provided for romanization")
            return nil
        }

        // Determine which romanization system to use
        let romanizationSystem = system ?? RomanizationSystem.defaultSystem(for: language)

        guard let romanizationSystem else {
            logger.debug("No romanization system available for language: \(language.minimalIdentifier)")
            return nil
        }

        logger.info("🔤 Romanizing text for \(language.minimalIdentifier) using \(romanizationSystem.rawValue)")

        // Perform the romanization
        let mutableString = NSMutableString(string: text)
        let transformed = CFStringTransform(
            mutableString as CFMutableString,
            nil,
            romanizationSystem.transformID,
            false
        )

        guard transformed else {
            logger.error("❌ Romanization failed for \(language.minimalIdentifier)")
            return nil
        }

        var result = mutableString as String

        // Strip diacritics if required (e.g., Pinyin without tones)
        if romanizationSystem.stripDiacritics {
            let mutableResult = NSMutableString(string: result)
            CFStringTransform(
                mutableResult as CFMutableString,
                nil,
                kCFStringTransformStripDiacritics,
                false
            )
            result = mutableResult as String
        }

        logger.info("✅ Romanization successful: \(result.prefix(50))...")
        return result
    }

    /// Get available romanization systems for a language
    func availableSystems(for language: Locale.Language) -> [RomanizationSystem] {
        RomanizationSystem.systems(for: language)
    }

    /// Detect the script used by a language
    func detectScript(for text: String, language: Locale.Language) -> Script {
        Script.detect(from: language)
    }

    /// Check if a language uses a non-Latin script and needs romanization
    func needsRomanization(language: Locale.Language) -> Bool {
        let script = Script.detect(from: language)
        return script.needsRomanization
    }
}
