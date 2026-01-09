//
//  AIAssistantService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import FoundationModels
import OSLog

/// Service for Apple Intelligence-powered translation enhancements using FoundationModels framework
///
/// Uses the on-device language model to provide contextual insights about translations,
/// including example sentences, alternatives, formality analysis, and cultural notes.
@MainActor
struct AIAssistantService {
    private let logger = Logger(subsystem: "com.lingko.app", category: "AIAssistant")
    private let model: SystemLanguageModel

    init() {
        self.model = .default
    }

    // MARK: - Availability

    /// Check if Apple Intelligence APIs are available
    var isAvailable: Bool {
        if #available(iOS 26.0, *) {
            switch model.availability {
            case .available:
                return true
            case .unavailable(let reason):
                logger.info("🤖 Model unavailable: \(String(describing: reason))")
                return false
            }
        }
        return false
    }

    // MARK: - Example Generation

    /// Generate example sentences using a translated word/phrase
    ///
    /// - Parameters:
    ///   - word: The translated word or phrase to use in examples
    ///   - language: The target language for examples
    /// - Returns: Array of example sentences, or empty array if unavailable
    func generateExamples(for word: String, in language: Locale.Language) async -> [String] {
        logger.info("🤖 Generating examples for '\(word)' in \(language.minimalIdentifier)")

        guard isAvailable else {
            return []
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
                let prompt = """
                Generate 3 short, natural example sentences using the word or phrase "\(word)" in \(languageName).
                Return only the sentences, one per line, without numbering or additional explanation.
                """

                let response = try await session.respond(to: prompt)
                let examples = response.content
                    .split(separator: "\n")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                logger.info("✅ Generated \(examples.count) examples")
                return Array(examples)
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation:
                    logger.info("ℹ️ Guardrail triggered for examples")
                    return []
                default:
                    logger.error("❌ Failed to generate examples: \(error.localizedDescription)")
                    return []
                }
            } catch {
                logger.error("❌ Failed to generate examples: \(error.localizedDescription)")
                return []
            }
        }

        return []
    }

    // MARK: - Alternative Translations

    /// Get alternative ways to express a translation with explanations
    ///
    /// - Parameters:
    ///   - text: The original text to translate
    ///   - sourceLanguage: The source language (optional, will be detected)
    ///   - targetLanguage: The target language for alternatives
    /// - Returns: Array of alternative translations, or empty array if unavailable
    func getAlternatives(
        for text: String,
        from sourceLanguage: Locale.Language?,
        to targetLanguage: Locale.Language
    ) async -> [Alternative] {
        let sourceLang = sourceLanguage?.minimalIdentifier ?? "auto"
        logger.info("🤖 Getting alternatives: \(sourceLang) -> \(targetLanguage.minimalIdentifier)")

        guard isAvailable else {
            return []
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let languageName = Locale.current.localizedString(forLanguageCode: targetLanguage.minimalIdentifier) ?? targetLanguage.minimalIdentifier
                let prompt = """
                Provide 3 alternative ways to say "\(text)" in \(languageName).
                For each alternative, provide:
                1. The alternative text
                2. A brief explanation of when and why to use it
                3. The formality level (very_formal, formal, neutral, informal, or very_informal)

                Format each alternative as:
                ALTERNATIVE: <text>
                EXPLANATION: <explanation>
                FORMALITY: <level>
                ---
                """

                let response = try await session.respond(to: prompt)
                let alternatives = parseAlternatives(from: response.content)
                logger.info("✅ Generated \(alternatives.count) alternatives")
                return alternatives
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation:
                    logger.info("ℹ️ Guardrail triggered for alternatives")
                    return []
                default:
                    logger.error("❌ Failed to generate alternatives: \(error.localizedDescription)")
                    return []
                }
            } catch {
                logger.error("❌ Failed to generate alternatives: \(error.localizedDescription)")
                return []
            }
        }

        return []
    }

    private func parseAlternatives(from text: String) -> [Alternative] {
        let blocks = text.components(separatedBy: "---").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        var alternatives: [Alternative] = []

        for block in blocks {
            guard !block.isEmpty else { continue }

            var altText: String?
            var explanation: String?
            var formalityStr: String?

            for line in block.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("ALTERNATIVE:") {
                    altText = trimmed.replacingOccurrences(of: "ALTERNATIVE:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("EXPLANATION:") {
                    explanation = trimmed.replacingOccurrences(of: "EXPLANATION:", with: "").trimmingCharacters(in: .whitespaces)
                } else if trimmed.hasPrefix("FORMALITY:") {
                    formalityStr = trimmed.replacingOccurrences(of: "FORMALITY:", with: "").trimmingCharacters(in: .whitespaces)
                }
            }

            if let altText = altText, let explanation = explanation {
                let formality = parseFormalityLevel(from: formalityStr ?? "neutral")
                alternatives.append(Alternative(
                    text: altText,
                    explanation: explanation,
                    formalityLevel: formality
                ))
            }
        }

        return alternatives
    }

    private func parseFormalityLevel(from text: String) -> FormalityLevel {
        let lowercased = text.lowercased()
        if lowercased.contains("very_formal") || lowercased.contains("very formal") {
            return .veryFormal
        } else if lowercased.contains("formal") {
            return .formal
        } else if lowercased.contains("very_informal") || lowercased.contains("very informal") {
            return .veryInformal
        } else if lowercased.contains("informal") {
            return .informal
        } else {
            return .neutral
        }
    }

    // MARK: - Formality Analysis

    /// Explain the formality level of a translation
    ///
    /// - Parameters:
    ///   - translation: The translated text to analyze
    ///   - language: The language of the translation
    /// - Returns: Explanation of formality level, or nil if unavailable
    func explainFormality(for translation: String, language: Locale.Language) async -> String? {
        logger.info("🤖 Explaining formality for '\(translation)' in \(language.minimalIdentifier)")

        guard isAvailable else {
            return nil
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
                let prompt = """
                Is "\(translation)" formal, informal, or neutral in \(languageName)?
                Explain the formality level and when to use this expression.
                """

                let response = try await session.respond(to: prompt)
                logger.info("✅ Formality explained")
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation:
                    logger.info("ℹ️ Guardrail triggered for formality explanation")
                    return nil
                default:
                    logger.error("❌ Failed to explain formality: \(error.localizedDescription)")
                    return nil
                }
            } catch {
                logger.error("❌ Failed to explain formality: \(error.localizedDescription)")
                return nil
            }
        }

        return nil
    }

    // MARK: - Formality Detection

    /// Detect the formality level of a translation
    ///
    /// - Parameters:
    ///   - translation: The translated text to analyze
    ///   - language: The language of the translation
    /// - Returns: The detected formality level, or nil if unavailable
    func detectFormality(for translation: String, language: Locale.Language) async -> FormalityLevel? {
        logger.info("🤖 Detecting formality for '\(translation)' in \(language.minimalIdentifier)")

        guard isAvailable else {
            return nil
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
                let prompt = """
                Classify the formality level of "\(translation)" in \(languageName).
                Return only one of these exact words: very_formal, formal, neutral, informal, very_informal
                """

                let response = try await session.respond(to: prompt)
                let formality = parseFormalityLevel(from: response.content)
                logger.info("✅ Formality detected: \(formality.rawValue)")
                return formality
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation:
                    logger.info("ℹ️ Guardrail triggered for formality detection")
                    return nil
                default:
                    logger.error("❌ Failed to detect formality: \(error.localizedDescription)")
                    return nil
                }
            } catch {
                logger.error("❌ Failed to detect formality: \(error.localizedDescription)")
                return nil
            }
        }

        return nil
    }

    // MARK: - Cultural Context

    /// Get cultural notes and usage context for a translation
    ///
    /// - Parameters:
    ///   - translation: The translated text
    ///   - language: The language of the translation
    /// - Returns: Cultural notes and context, or nil if unavailable
    func getCulturalNotes(for translation: String, in language: Locale.Language) async -> String? {
        logger.info("🤖 Getting cultural notes for '\(translation)' in \(language.minimalIdentifier)")

        guard isAvailable else {
            return nil
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
                let prompt = """
                Explain cultural context and usage notes for "\(translation)" in \(languageName).
                Keep it very concise (1-2 sentences maximum).
                """

                let response = try await session.respond(to: prompt)
                logger.info("✅ Cultural notes retrieved")
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation:
                    logger.info("ℹ️ Guardrail triggered for cultural notes")
                    return nil
                default:
                    logger.error("❌ Failed to get cultural notes: \(error.localizedDescription)")
                    return nil
                }
            } catch {
                logger.error("❌ Failed to get cultural notes: \(error.localizedDescription)")
                return nil
            }
        }

        return nil
    }

    // MARK: - Idiom Explanation

    /// Explain an idiom with both literal and figurative meanings
    ///
    /// - Parameters:
    ///   - text: The idiomatic expression
    ///   - language: The language of the idiom
    /// - Returns: Explanation including literal and figurative meanings, or nil if unavailable
    func explainIdiom(_ text: String, in language: Locale.Language) async -> String? {
        logger.info("🤖 Explaining idiom '\(text)' in \(language.minimalIdentifier)")

        guard isAvailable else {
            return nil
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
                let prompt = """
                Explain the idiom "\(text)" in \(languageName).
                Provide:
                1. The literal word-by-word meaning
                2. The figurative/actual meaning
                3. When and how it's commonly used
                """

                let response = try await session.respond(to: prompt)
                logger.info("✅ Idiom explained")
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation:
                    logger.info("ℹ️ Guardrail triggered for idiom explanation")
                    return nil
                default:
                    logger.error("❌ Failed to explain idiom: \(error.localizedDescription)")
                    return nil
                }
            } catch {
                logger.error("❌ Failed to explain idiom: \(error.localizedDescription)")
                return nil
            }
        }

        return nil
    }

    // MARK: - General Question

    /// Ask a general question about a translation
    ///
    /// - Parameters:
    ///   - question: The user's question
    ///   - translation: The translation being asked about
    ///   - language: The language of the translation
    /// - Returns: Answer to the question, or nil if unavailable
    func askAboutTranslation(
        question: String,
        translation: String,
        language: Locale.Language
    ) async -> String? {
        logger.info("🤖 Question about '\(translation)': \(question)")

        guard isAvailable else {
            return nil
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let languageName = Locale.current.localizedString(forLanguageCode: language.minimalIdentifier) ?? language.minimalIdentifier
                let prompt = """
                Context: The translation "\(translation)" in \(languageName)
                Question: \(question)

                Provide a helpful, concise answer about this translation.
                """

                let response = try await session.respond(to: prompt)
                logger.info("✅ Question answered")
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                switch error {
                case .guardrailViolation:
                    logger.info("ℹ️ Guardrail triggered for question")
                    return nil
                default:
                    logger.error("❌ Failed to answer question: \(error.localizedDescription)")
                    return nil
                }
            } catch {
                logger.error("❌ Failed to answer question: \(error.localizedDescription)")
                return nil
            }
        }

        return nil
    }
}
