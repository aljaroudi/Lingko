//
//  TranslationService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
@preconcurrency import Translation
import NaturalLanguage
import OSLog

@MainActor
struct TranslationService {
    private let logger = Logger(subsystem: "com.lingko.translation", category: "service")
    private let languageAvailability = LanguageAvailability()

    // MARK: - Language Availability

    /// Get all supported languages from the Translation framework
    func getSupportedLanguages() async -> [Locale.Language] {
        logger.info("📚 Fetching supported languages from Translation framework")
        let languages = await languageAvailability.supportedLanguages
        logger.info("✅ Found \(languages.count) supported languages")
        return languages
    }

    /// Check if a language pair is installed and ready for offline translation
    func isLanguageInstalled(from source: Locale.Language, to target: Locale.Language) async -> Bool {
        let status = await languageAvailability.status(from: source, to: target)
        return status == .installed
    }

    /// Get the availability status for a language pair
    func getLanguageStatus(from source: Locale.Language, to target: Locale.Language) async -> LanguageAvailability.Status {
        await languageAvailability.status(from: source, to: target)
    }

    // MARK: - Language Detection

    /// Detects the dominant language in the given text with confidence score
    func detectLanguage(for text: String) -> (language: Locale.Language?, confidence: Double) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Empty text provided for language detection")
            return (nil, 0.0)
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        guard let dominantLanguage = recognizer.dominantLanguage,
              let hypotheses = recognizer.languageHypotheses(withMaximum: 1).first else {
            logger.warning("Failed to detect language")
            return (nil, 0.0)
        }

        let confidence = hypotheses.value
        let localeLanguage = Locale.Language(identifier: dominantLanguage.rawValue)

        logger.info("Detected language: \(dominantLanguage.rawValue) with confidence: \(confidence)")
        return (localeLanguage, confidence)
    }

    // MARK: - Translation

    /// Translates text to all specified target languages concurrently
    func translateToAll(
        text: String,
        from sourceLanguage: Locale.Language?,
        to targetLanguages: Set<Locale.Language>
    ) async -> [TranslationResult] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Empty text provided for translation")
            return []
        }

        guard !targetLanguages.isEmpty else {
            logger.debug("No target languages specified")
            return []
        }

        // Detect source language if not provided
        let (detectedLanguage, confidence) = sourceLanguage == nil
            ? detectLanguage(for: text)
            : (sourceLanguage, 1.0)

        guard let sourceLanguage = detectedLanguage else {
            logger.error("Could not determine source language")
            return []
        }

        logger.info("🌍 Starting translation from \(sourceLanguage.minimalIdentifier) to \(targetLanguages.count) target languages")

        // Use TaskGroup for concurrent translations
        return await withTaskGroup(of: TranslationResult?.self) { group in
            for targetLanguage in targetLanguages {
                // Skip if target is same as source
                guard targetLanguage != sourceLanguage else {
                    logger.info("⏭️  Skipping translation to source language: \(targetLanguage.minimalIdentifier)")
                    continue
                }

                // Check availability before attempting translation
                let status = await getLanguageStatus(from: sourceLanguage, to: targetLanguage)
                guard status == .installed else {
                    logger.warning("⚠️  Language pair not installed: \(sourceLanguage.minimalIdentifier) -> \(targetLanguage.minimalIdentifier) (status: \(String(describing: status)))")
                    continue
                }

                group.addTask {
                    await translateSingle(
                        text: text,
                        from: sourceLanguage,
                        to: targetLanguage,
                        detectionConfidence: confidence
                    )
                }
            }

            var results: [TranslationResult] = []
            var failedCount = 0

            for await result in group {
                if let result {
                    results.append(result)
                } else {
                    failedCount += 1
                }
            }

            let attemptedCount = targetLanguages.count - (targetLanguages.contains(sourceLanguage) ? 1 : 0)
            logger.info("✅ Completed \(results.count)/\(attemptedCount) translations (\(failedCount) failed or skipped)")

            if results.isEmpty && attemptedCount > 0 {
                logger.error("❌ No translations completed. Possible reasons:")
                logger.error("   • Language packs not installed")
                logger.error("   • Running on simulator (limited Translation support)")
                logger.error("   • All selected languages are the same as source")
            }

            return results.sorted { $0.languageName < $1.languageName }
        }
    }

    // MARK: - Private Methods

    /// Translates text from source to target language
    private func translateSingle(
        text: String,
        from sourceLanguage: Locale.Language,
        to targetLanguage: Locale.Language,
        detectionConfidence: Double
    ) async -> TranslationResult? {
        do {
            let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            let response = try await session.translate(text)

            logger.debug("Translation successful: \(sourceLanguage.minimalIdentifier) -> \(targetLanguage.minimalIdentifier)")

            return TranslationResult(
                language: targetLanguage,
                sourceLanguage: sourceLanguage,
                translation: response.targetText,
                detectionConfidence: detectionConfidence
            )
        } catch {
            logger.error("Translation failed for \(targetLanguage.minimalIdentifier): \(error.localizedDescription)")
            return nil
        }
    }
}
