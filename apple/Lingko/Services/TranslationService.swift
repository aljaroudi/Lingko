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
        let status = await getLanguageStatus(from: source, to: target)
        return status == .installed
    }

    /// Check if a language pair is installed using a preloaded supported-language list.
    func isLanguageInstalled(
        from source: Locale.Language,
        to target: Locale.Language,
        supportedLanguages: [Locale.Language]
    ) async -> Bool {
        let status = await getLanguageStatus(from: source, to: target, supportedLanguages: supportedLanguages)
        return status == .installed
    }

    /// Get the availability status for a language pair
    func getLanguageStatus(from source: Locale.Language, to target: Locale.Language) async -> LanguageAvailability.Status {
        let supportedLanguages = await getSupportedLanguages()
        return await getLanguageStatus(from: source, to: target, supportedLanguages: supportedLanguages)
    }

    /// Get the availability status for a language pair using a preloaded supported-language list.
    func getLanguageStatus(
        from source: Locale.Language,
        to target: Locale.Language,
        supportedLanguages: [Locale.Language]
    ) async -> LanguageAvailability.Status {
        guard isValidPair(source: source, target: target, supportedLanguages: supportedLanguages) else {
            return .unsupported
        }

        return await languageAvailability.status(from: source, to: target)
    }

    func isLanguageSupported(_ language: Locale.Language, in supportedLanguages: [Locale.Language]) -> Bool {
        let supportedIDs = Set(supportedLanguages.map { canonicalLanguageIdentifier(for: $0) })
        return supportedIDs.contains(canonicalLanguageIdentifier(for: language))
    }

    func isSameLanguage(_ lhs: Locale.Language, _ rhs: Locale.Language) -> Bool {
        canonicalLanguageIdentifier(for: lhs) == canonicalLanguageIdentifier(for: rhs)
    }

    func installedLanguages(
        from languageInfos: [LanguageInfo] = SupportedLanguages.all,
        referenceLanguage: Locale.Language = Locale.Language(identifier: "en")
    ) async -> Set<Locale.Language> {
        let supportedLanguages = await getSupportedLanguages()
        var installed: Set<Locale.Language> = []

        if isLanguageSupported(referenceLanguage, in: supportedLanguages) {
            installed.insert(canonicalLanguage(for: referenceLanguage))
        }

        for languageInfo in languageInfos {
            let language = languageInfo.language

            guard !isSameLanguage(referenceLanguage, language),
                  isLanguageSupported(language, in: supportedLanguages) else {
                continue
            }

            let status = await getLanguageStatus(
                from: referenceLanguage,
                to: language,
                supportedLanguages: supportedLanguages
            )

            if status == .installed {
                installed.insert(language)
            }
        }

        return installed
    }

    // MARK: - Linguistic Analysis Support

    /// Check if a language supports linguistic analysis (POS tagging and named entity recognition)
    func supportsLinguisticAnalysis(for language: Locale.Language) -> Bool {
        let nlLanguage = NLLanguage(rawValue: language.minimalIdentifier)

        // Check if the language supports both lexical class (POS) and name type (NER) tag schemes
        let supportsLexicalClass = NLTagger.availableTagSchemes(for: .word, language: nlLanguage).contains(.lexicalClass)
        let supportsNameType = NLTagger.availableTagSchemes(for: .word, language: nlLanguage).contains(.nameType)

        return supportsLexicalClass && supportsNameType
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
            .nameType           // Named entity recognition
        ])

        tagger.string = text

        // Set language if provided for better accuracy
        if let language {
            let nlLanguage = NLLanguage(rawValue: language.minimalIdentifier)
            tagger.setLanguage(nlLanguage, range: text.startIndex..<text.endIndex)
        }

        // Extract named entities
        let entities = extractEntities(from: text, tagger: tagger)

        // Extract tokens with POS tags and lemmas
        let tokens = extractTokens(from: text, tagger: tagger)

        // Get dominant language
        let (detectedLanguage, confidence) = detectLanguage(for: text)
        let nlLanguage = detectedLanguage.flatMap { NLLanguage(rawValue: $0.minimalIdentifier) }

        logger.info("✅ Linguistic analysis complete: \(entities.count) entities, \(tokens.count) tokens")

        return LinguisticAnalysis(
            entities: entities,
            tokens: tokens,
            dominantLanguage: nlLanguage,
            languageConfidence: confidence
        )
    }

    // MARK: - Private Linguistic Analysis Helpers

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

    /// Translates text to a single target language.
    func translate(
        text: String,
        from sourceLanguage: Locale.Language,
        to targetLanguage: Locale.Language,
        includeRomanization: Bool = true,
        romanizationService: RomanizationService = RomanizationService()
    ) async -> TranslationResult? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.debug("Empty text provided for translation")
            return nil
        }

        let supportedLanguages = await getSupportedLanguages()
        guard isValidPair(source: sourceLanguage, target: targetLanguage, supportedLanguages: supportedLanguages) else {
            return nil
        }

        let status = await getLanguageStatus(
            from: sourceLanguage,
            to: targetLanguage,
            supportedLanguages: supportedLanguages
        )
        guard status == .installed else {
            logger.warning("⚠️  Language pair not installed: \(sourceLanguage.minimalIdentifier) -> \(targetLanguage.minimalIdentifier) (status: \(String(describing: status)))")
            return nil
        }

        let sourceRomanization = includeRomanization && romanizationService.needsRomanization(language: sourceLanguage)
            ? romanizationService.romanize(text: text, language: sourceLanguage)
            : nil

        logger.info("🌍 Starting translation from \(sourceLanguage.minimalIdentifier) to \(targetLanguage.minimalIdentifier)")

        return await translateSingle(
            text: text,
            from: sourceLanguage,
            to: targetLanguage,
            detectionConfidence: 1.0,
            includeRomanization: includeRomanization,
            romanizationService: romanizationService,
            sourceRomanization: sourceRomanization
        )
    }

    /// Translates text to all specified target languages with optional prioritization
    /// - Parameter priorityLanguage: If provided, this language will be translated first before others
    func translateToAll(
        text: String,
        from sourceLanguage: Locale.Language?,
        to targetLanguages: Set<Locale.Language>,
        priorityLanguage: Locale.Language? = nil,
        includeRomanization: Bool = true,
        romanizationService: RomanizationService = RomanizationService(),
        onEachResult: (@MainActor @Sendable (TranslationResult) async -> Void)? = nil
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

        let supportedLanguages = await getSupportedLanguages()
        let validTargetLanguages = targetLanguages.filter {
            isValidPair(source: sourceLanguage, target: $0, supportedLanguages: supportedLanguages)
        }

        guard !validTargetLanguages.isEmpty else {
            logger.debug("No valid target languages for source \(sourceLanguage.minimalIdentifier)")
            return []
        }

        logger.info("🌍 Starting translation from \(sourceLanguage.minimalIdentifier) to \(validTargetLanguages.count) target languages")

        // Romanize source text if needed
        let sourceRomanization = includeRomanization && romanizationService.needsRomanization(language: sourceLanguage)
            ? romanizationService.romanize(text: text, language: sourceLanguage)
            : nil

        var results: [TranslationResult] = []

        // If there's a priority language, translate it first
        if let priority = priorityLanguage, validTargetLanguages.contains(priority) {
            let status = await getLanguageStatus(
                from: sourceLanguage,
                to: priority,
                supportedLanguages: supportedLanguages
            )
            if status == .installed {
                logger.info("🎯 Translating priority language first: \(priority.minimalIdentifier)")
                if let result = await translateSingle(
                    text: text,
                    from: sourceLanguage,
                    to: priority,
                    detectionConfidence: confidence,
                    includeRomanization: includeRomanization,
                    romanizationService: romanizationService,
                    sourceRomanization: sourceRomanization
                ) {
                    results.append(result)
                    // Call the completion handler immediately for priority result
                    if let handler = onEachResult {
                        await handler(result)
                    }
                }
            }
        }

        // Get remaining languages (excluding priority if already translated)
        let remainingLanguages = validTargetLanguages.filter { language in
            !results.contains(where: { $0.language == language })
        }

        // Use TaskGroup for concurrent translations of remaining languages
        let remainingResults = await withTaskGroup(of: TranslationResult?.self) { group in
            for targetLanguage in remainingLanguages {
                // Check availability before attempting translation
                let status = await getLanguageStatus(
                    from: sourceLanguage,
                    to: targetLanguage,
                    supportedLanguages: supportedLanguages
                )
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
                        romanizationService: romanizationService,
                        sourceRomanization: sourceRomanization
                    )
                }
            }

            var groupResults: [TranslationResult] = []
            var failedCount = 0

            for await result in group {
                if let result {
                    groupResults.append(result)
                    // Call the completion handler immediately for each result
                    if let handler = onEachResult {
                        await handler(result)
                    }
                } else {
                    failedCount += 1
                }
            }

            return groupResults
        }

        results.append(contentsOf: remainingResults)

        let attemptedCount = validTargetLanguages.count
        logger.info("✅ Completed \(results.count)/\(attemptedCount) translations")

        if results.isEmpty && attemptedCount > 0 {
            logger.error("❌ No translations completed. Possible reasons:")
            logger.error("   • Language packs not installed")
            logger.error("   • Running on simulator (limited Translation support)")
            logger.error("   • All selected languages are the same as source")
        }

        return results.sorted { $0.languageName < $1.languageName }
    }

    // MARK: - Private Methods

    /// Translates text from source to target language
    private func translateSingle(
        text: String,
        from sourceLanguage: Locale.Language,
        to targetLanguage: Locale.Language,
        detectionConfidence: Double,
        includeRomanization: Bool,
        romanizationService: RomanizationService,
        sourceRomanization: String?
    ) async -> TranslationResult? {
        guard !isSameLanguage(sourceLanguage, targetLanguage) else {
            logger.debug("Skipping same-language translation")
            return nil
        }

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

            return TranslationResult(
                language: targetLanguage,
                sourceLanguage: sourceLanguage,
                translation: response.targetText,
                detectionConfidence: detectionConfidence,
                romanization: targetRomanization,
                sourceRomanization: sourceRomanization,
                romanizationSystem: romanizationSystem,
                linguisticAnalysis: nil
            )
        } catch {
            logger.error("Translation failed for \(targetLanguage.minimalIdentifier): \(error.localizedDescription)")
            return nil
        }
    }

    private func isValidPair(
        source: Locale.Language,
        target: Locale.Language,
        supportedLanguages: [Locale.Language]
    ) -> Bool {
        guard !isSameLanguage(source, target) else {
            logger.debug("Skipping same-language pair: \(source.minimalIdentifier) -> \(target.minimalIdentifier)")
            return false
        }

        guard isLanguageSupported(source, in: supportedLanguages),
              isLanguageSupported(target, in: supportedLanguages) else {
            logger.debug("Skipping unsupported pair: \(source.minimalIdentifier) -> \(target.minimalIdentifier)")
            return false
        }

        return true
    }

    private func canonicalLanguage(for language: Locale.Language) -> Locale.Language {
        Locale.Language(identifier: canonicalLanguageIdentifier(for: language))
    }

    private func canonicalLanguageIdentifier(for language: Locale.Language) -> String {
        canonicalLanguageIdentifier(language.minimalIdentifier)
    }

    private func canonicalLanguageIdentifier(_ identifier: String) -> String {
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        let parts = normalized.split(separator: "-").map(String.init)
        guard let base = parts.first else { return normalized }

        switch base {
        case "zh":
            if parts.contains("hant") { return "zh-hant" }
            return "zh-hans"
        case "pt":
            return "pt-br"
        default:
            return base
        }
    }
}
