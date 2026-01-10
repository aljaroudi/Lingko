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

    /// Detects multiple languages in the given text with confidence scores and download status
    /// - Parameters:
    ///   - text: The text to analyze
    ///   - preferredLanguages: Optional set of languages to boost confidence for (e.g., user-selected languages)
    ///   - installedLanguages: Optional set of installed/downloaded languages to check availability
    ///   - maxResults: Maximum number of results to return (default: 5)
    /// - Returns: Array of detected languages with confidence scores and download status, filtered to supported languages only
    func detectLanguages(
        for text: String,
        preferredLanguages: Set<Locale.Language>? = nil,
        installedLanguages: Set<Locale.Language>? = nil,
        maxResults: Int = 5
    ) -> [(language: Locale.Language, confidence: Double, isDownloaded: Bool)] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Empty text provided for language detection")
            return []
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)

        // Get top language hypotheses
        let hypotheses = recognizer.languageHypotheses(withMaximum: 10)
        
        guard !hypotheses.isEmpty else {
            logger.warning("Failed to detect any languages")
            return []
        }

        // Convert to supported languages list
        let supportedLanguageIds = Set(SupportedLanguages.allLanguages.map { $0.minimalIdentifier })
        let preferredLanguageIds = preferredLanguages.map { Set($0.map { $0.minimalIdentifier }) }
        let installedLanguageIds = installedLanguages.map { Set($0.map { $0.minimalIdentifier }) }
        
        var results: [(language: Locale.Language, confidence: Double, isDownloaded: Bool)] = []
        
        for (nlLanguage, confidence) in hypotheses {
            let localeLanguage = Locale.Language(identifier: nlLanguage.rawValue)
            let languageId = localeLanguage.minimalIdentifier
            
            // Only include supported languages
            guard supportedLanguageIds.contains(languageId) else {
                logger.debug("Filtering out unsupported language: \(languageId)")
                continue
            }
            
            // Check if language is downloaded
            let isDownloaded = installedLanguageIds?.contains(languageId) ?? true
            
            // Apply confidence boost for preferred languages
            var adjustedConfidence = confidence
            if let preferredIds = preferredLanguageIds, preferredIds.contains(languageId) {
                adjustedConfidence = min(1.0, confidence + 0.2)
                logger.debug("Boosting confidence for preferred language \(languageId): \(confidence) -> \(adjustedConfidence)")
            }
            
            results.append((language: localeLanguage, confidence: adjustedConfidence, isDownloaded: isDownloaded))
        }
        
        // Sort by confidence (descending) and limit results
        results.sort { $0.confidence > $1.confidence }
        let limitedResults = Array(results.prefix(maxResults))
        
        logger.info("Detected \(limitedResults.count) supported languages: \(limitedResults.map { "\($0.language.minimalIdentifier)(\(String(format: "%.2f", $0.confidence)))\($0.isDownloaded ? "✓" : "⬇️")" }.joined(separator: ", "))")
        
        return limitedResults
    }

    /// Detects the dominant language in the given text with confidence score
    /// - Parameter text: The text to analyze
    /// - Returns: The most likely language and its confidence score
    /// - Note: This method is kept for backward compatibility. Use `detectLanguages(for:preferredLanguages:installedLanguages:)` for multi-language detection.
    func detectLanguage(for text: String) -> (language: Locale.Language?, confidence: Double) {
        let results = detectLanguages(for: text, preferredLanguages: nil, installedLanguages: nil, maxResults: 1)
        return results.first.map { ($0.language, $0.confidence) } ?? (nil, 0.0)
    }

    // MARK: - Linguistic Analysis

    /// Perform comprehensive linguistic analysis on text
    func analyzeLinguistics(for text: String, language: Locale.Language? = nil) -> LinguisticAnalysis? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Empty text provided for linguistic analysis")
            return nil
        }

        logger.info("🔬 Starting linguistic analysis for text")

        let tagger = NLTagger(tagSchemes: [
            .tokenType,
            .lexicalClass,      // POS tagging
            .lemma,             // Base forms
            .nameType,          // Named entity recognition
            .sentimentScore     // Sentiment analysis
        ])

        tagger.string = text

        // Set language if provided for better accuracy
        if let language {
            let nlLanguage = NLLanguage(rawValue: language.minimalIdentifier)
            tagger.setLanguage(nlLanguage, range: text.startIndex..<text.endIndex)
        }

        // Extract sentiment
        let sentiment = extractSentiment(from: text, tagger: tagger)

        // Extract named entities
        let entities = extractEntities(from: text, tagger: tagger)

        // Extract tokens with POS tags and lemmas
        let tokens = extractTokens(from: text, tagger: tagger)

        // Get dominant language
        let (detectedLanguage, confidence) = detectLanguage(for: text)
        let nlLanguage = detectedLanguage.flatMap { NLLanguage(rawValue: $0.minimalIdentifier) }

        logger.info("✅ Linguistic analysis complete: \(entities.count) entities, \(tokens.count) tokens, sentiment: \(sentiment?.description ?? "none")")

        return LinguisticAnalysis(
            sentiment: sentiment,
            entities: entities,
            tokens: tokens,
            dominantLanguage: nlLanguage,
            languageConfidence: confidence
        )
    }

    // MARK: - Private Linguistic Analysis Helpers

    private func extractSentiment(from text: String, tagger: NLTagger) -> Double? {
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)

        if let tag, let score = Double(tag.rawValue) {
            logger.debug("Sentiment score: \(score)")
            return score
        }

        return nil
    }

    private func extractEntities(from text: String, tagger: NLTagger) -> [NamedEntity] {
        var entities: [NamedEntity] = []
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .nameType) { tag, tokenRange in
            if let tag, [.personalName, .placeName, .organizationName].contains(tag) {
                let entityText = String(text[tokenRange])
                let entity = NamedEntity(text: entityText, type: tag)
                entities.append(entity)
                logger.debug("Found entity: \(entityText) (\(tag.rawValue))")
            }
            return true
        }

        return entities
    }

    private func extractTokens(from text: String, tagger: NLTagger) -> [LinguisticToken] {
        var tokens: [LinguisticToken] = []
        let range = text.startIndex..<text.endIndex

        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass) { posTag, tokenRange in
            // Filter out punctuation, whitespace, and other non-word tokens
            guard let posTag, posTag != .punctuation, posTag != .whitespace, posTag != .otherWord else {
                return true
            }

            let tokenText = String(text[tokenRange])

            // Skip tokens that are purely whitespace or punctuation
            guard !tokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !tokenText.trimmingCharacters(in: .punctuationCharacters).isEmpty else {
                return true
            }

            // Get lemma for this token
            let (lemmaTag, _) = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lemma)
            let lemma = lemmaTag?.rawValue

            let token = LinguisticToken(
                text: tokenText,
                lemma: lemma,
                partOfSpeech: posTag
            )
            tokens.append(token)

            return true
        }

        logger.debug("Extracted \(tokens.count) tokens")
        return tokens
    }

    // MARK: - Translation

    /// Translates text to all specified target languages concurrently
    func translateToAll(
        text: String,
        from sourceLanguage: Locale.Language?,
        to targetLanguages: Set<Locale.Language>,
        includeLinguisticAnalysis: Bool = false,
        includeRomanization: Bool = true,
        romanizationService: RomanizationService = RomanizationService()
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

        // Romanize source text if needed
        let sourceRomanization = includeRomanization && romanizationService.needsRomanization(language: sourceLanguage)
            ? romanizationService.romanize(text: text, language: sourceLanguage)
            : nil

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
                        detectionConfidence: confidence,
                        includeRomanization: includeRomanization,
                        includeLinguisticAnalysis: includeLinguisticAnalysis,
                        romanizationService: romanizationService,
                        sourceRomanization: sourceRomanization
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
        detectionConfidence: Double,
        includeRomanization: Bool,
        includeLinguisticAnalysis: Bool,
        romanizationService: RomanizationService,
        sourceRomanization: String?
    ) async -> TranslationResult? {
        do {
            let session = TranslationSession(installedSource: sourceLanguage, target: targetLanguage)
            let response = try await session.translate(text)

            logger.debug("Translation successful: \(sourceLanguage.minimalIdentifier) -> \(targetLanguage.minimalIdentifier)")

            // Romanize target translation if needed
            var targetRomanization: String?
            var romanizationSystem: RomanizationSystem?

            if includeRomanization && romanizationService.needsRomanization(language: targetLanguage) {
                targetRomanization = romanizationService.romanize(
                    text: response.targetText,
                    language: targetLanguage
                )
                romanizationSystem = RomanizationSystem.defaultSystem(for: targetLanguage)
            }

            // Perform linguistic analysis on translated text if requested
            let linguisticAnalysis = includeLinguisticAnalysis
                ? analyzeLinguistics(for: response.targetText, language: targetLanguage)
                : nil

            return TranslationResult(
                language: targetLanguage,
                sourceLanguage: sourceLanguage,
                translation: response.targetText,
                detectionConfidence: detectionConfidence,
                romanization: targetRomanization,
                sourceRomanization: sourceRomanization,
                romanizationSystem: romanizationSystem,
                linguisticAnalysis: linguisticAnalysis
            )
        } catch {
            logger.error("Translation failed for \(targetLanguage.minimalIdentifier): \(error.localizedDescription)")
            return nil
        }
    }
}
