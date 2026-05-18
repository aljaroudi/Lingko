//
//  AIAssistantService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import FoundationModels
import OSLog

@MainActor
struct AIAssistantService {
    private let logger = Logger(subsystem: "com.lingko.app", category: "AIAssistant")
    private let model: SystemLanguageModel

    init() {
        self.model = .default
    }

    // MARK: - Availability

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

    func generateExamples(for word: String, in language: Locale.Language) async -> [String] {
        logger.info("🤖 Generating examples for '\(word)' in \(language.minimalIdentifier)")
        guard isAvailable else { return [] }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let prompt = "Generate 3 short, natural example sentences using \"\(word)\" in \(language.nameOrId)."
                let response = try await session.respond(to: prompt, generating: GenerableExamples.self)
                logger.info("✅ Generated \(response.content.sentences.count) examples")
                return response.content.sentences
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error { logger.info("ℹ️ Guardrail triggered for examples") }
                else { logger.error("❌ Failed to generate examples: \(error.localizedDescription)") }
                return []
            } catch {
                logger.error("❌ Failed to generate examples: \(error.localizedDescription)")
                return []
            }
        }
        return []
    }

    // MARK: - Alternative Translations

    func getAlternatives(
        for text: String,
        from sourceLanguage: Locale.Language?,
        to targetLanguage: Locale.Language
    ) async -> [Alternative] {
        let sourceLang = sourceLanguage?.minimalIdentifier ?? "auto"
        logger.info("🤖 Getting alternatives: \(sourceLang) -> \(targetLanguage.minimalIdentifier)")
        guard isAvailable else { return [] }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let prompt = "Provide 3 alternative translations for \"\(text)\" in \(targetLanguage.nameOrId), varying in formality."
                let response = try await session.respond(to: prompt, generating: GenerableAlternatives.self)
                let alternatives = response.content.alternatives.map {
                    Alternative(text: $0.text, explanation: $0.explanation, formalityLevel: $0.formality.domain)
                }
                logger.info("✅ Generated \(alternatives.count) alternatives")
                return alternatives
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error { logger.info("ℹ️ Guardrail triggered for alternatives") }
                else { logger.error("❌ Failed to generate alternatives: \(error.localizedDescription)") }
                return []
            } catch {
                logger.error("❌ Failed to generate alternatives: \(error.localizedDescription)")
                return []
            }
        }
        return []
    }

    // MARK: - Cultural Context

    func getCulturalNotes(for translation: String, in language: Locale.Language) async -> String? {
        logger.info("🤖 Getting cultural notes for '\(translation)' in \(language.minimalIdentifier)")
        guard isAvailable else { return nil }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let prompt = "Explain cultural context and usage for \"\(translation)\" in \(language.nameOrId). Keep it to 1-2 sentences."
                let response = try await session.respond(to: prompt)
                logger.info("✅ Cultural notes retrieved")
                return response.content
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error { logger.info("ℹ️ Guardrail triggered for cultural notes") }
                else { logger.error("❌ Failed to get cultural notes: \(error.localizedDescription)") }
                return nil
            } catch {
                logger.error("❌ Failed to get cultural notes: \(error.localizedDescription)")
                return nil
            }
        }
        return nil
    }

    // MARK: - Tag Suggestions

    func suggestTags(for text: String, existingTagNames: [String]) async -> [String] {
        logger.info("🤖 Suggesting tags for text: \(text.prefix(50))...")
        guard isAvailable, !existingTagNames.isEmpty else {
            logger.debug("AI not available or no existing tags, skipping tag suggestions")
            return []
        }

        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(model: model)
                let tagList = existingTagNames.joined(separator: ", ")
                let prompt = "Available tags: \(tagList)\nText: \"\(text)\"\nSelect 0-3 tags from the list that best categorize this text. Return empty array if none fit."
                let response = try await session.respond(to: prompt, generating: GenerableTagSelection.self)
                let matchingTags = response.content.selectedTags
                    .filter { tag in existingTagNames.contains(where: { $0.lowercased() == tag.lowercased() }) }
                let suggestions = Array(matchingTags[..<min(3, matchingTags.count)])
                logger.info("✅ Suggested \(suggestions.count) tags: \(suggestions.joined(separator: ", "))")
                return suggestions
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error { logger.info("ℹ️ Guardrail triggered for tag suggestions") }
                else { logger.error("❌ Failed to suggest tags: \(error.localizedDescription)") }
                return []
            } catch {
                logger.error("❌ Failed to suggest tags: \(error.localizedDescription)")
                return []
            }
        }
        return []
    }
}

// MARK: - Generable DTOs

@available(iOS 26.0, *)
@Generable
private struct GenerableExamples {
    @Guide(description: "Three short, natural example sentences")
    var sentences: [String]
}

@available(iOS 26.0, *)
@Generable
private enum GenerableFormality {
    case veryFormal, formal, neutral, informal, veryInformal

    var domain: FormalityLevel {
        switch self {
        case .veryFormal: return .veryFormal
        case .formal: return .formal
        case .neutral: return .neutral
        case .informal: return .informal
        case .veryInformal: return .veryInformal
        }
    }
}

@available(iOS 26.0, *)
@Generable
private struct GenerableAlternative {
    @Guide(description: "The alternative translation text")
    var text: String
    @Guide(description: "When and why to use this version, in one short sentence")
    var explanation: String
    var formality: GenerableFormality
}

@available(iOS 26.0, *)
@Generable
private struct GenerableAlternatives {
    @Guide(.count(3))
    var alternatives: [GenerableAlternative]
}

@available(iOS 26.0, *)
@Generable
private struct GenerableTagSelection {
    @Guide(description: "Tag names selected from the provided list. Empty if none fit.")
    var selectedTags: [String]
}

// MARK: - Locale.Language helpers

extension Locale.Language {
    var nameOrId: String {
        Locale.current.localizedString(forLanguageCode: self.minimalIdentifier) ?? self.minimalIdentifier
    }
}
