//
//  TranslationMemoryService.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import Foundation
import SwiftData
import OSLog

@MainActor
struct TranslationMemoryService {
    private let logger = Logger(subsystem: "com.lingko.translation-memory", category: "service")

    private let minimumSimilarity: Double = 0.7  // 70% similarity threshold
    private let maximumSuggestions = 5

    // MARK: - Translation Memory Suggestions

    /// Find similar translations from history
    func findSimilarTranslations(
        for text: String,
        context: ModelContext
    ) -> [TranslationMemorySuggestion] {
        logger.debug("🔍 Finding similar translations for: \(text.prefix(50))...")

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        // Fetch recent translations from history
        let descriptor = FetchDescriptor<SavedTranslation>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            let allTranslations = try context.fetch(descriptor)
            logger.debug("📚 Checking \(allTranslations.count) saved translations")

            var suggestions: [TranslationMemorySuggestion] = []

            for savedTranslation in allTranslations {
                let similarity = calculateSimilarity(
                    between: text,
                    and: savedTranslation.sourceText
                )

                if similarity >= minimumSimilarity {
                    let suggestion = TranslationMemorySuggestion(
                        sourceText: savedTranslation.sourceText,
                        translations: savedTranslation.decodedTranslations ?? [],
                        similarity: similarity,
                        lastUsed: savedTranslation.timestamp
                    )
                    suggestions.append(suggestion)
                }

                // Early exit if we have enough suggestions
                if suggestions.count >= maximumSuggestions {
                    break
                }
            }

            // Sort by similarity (highest first)
            suggestions.sort { $0.similarity > $1.similarity }

            logger.info("✅ Found \(suggestions.count) similar translations")
            return Array(suggestions.prefix(maximumSuggestions))

        } catch {
            logger.error("❌ Failed to fetch translations: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: - Similarity Calculation

    /// Calculate similarity between two strings using normalized Levenshtein distance
    private func calculateSimilarity(between text1: String, and text2: String) -> Double {
        let normalized1 = text1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = text2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Quick exact match check
        if normalized1 == normalized2 {
            return 1.0
        }

        // Quick substring check
        if normalized1.contains(normalized2) || normalized2.contains(normalized1) {
            let longer = max(normalized1.count, normalized2.count)
            let shorter = min(normalized1.count, normalized2.count)
            return Double(shorter) / Double(longer) * 0.95  // Slightly penalize partial matches
        }

        // Calculate Levenshtein distance
        let distance = levenshteinDistance(normalized1, normalized2)
        let maxLength = max(normalized1.count, normalized2.count)

        guard maxLength > 0 else { return 0.0 }

        // Convert distance to similarity (0.0 to 1.0)
        let similarity = 1.0 - (Double(distance) / Double(maxLength))

        return max(0.0, min(1.0, similarity))
    }

    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ str1: String, _ str2: String) -> Int {
        let array1 = Array(str1)
        let array2 = Array(str2)

        let count1 = array1.count
        let count2 = array2.count

        // Early return for empty strings
        if count1 == 0 { return count2 }
        if count2 == 0 { return count1 }

        // Initialize distance matrix
        var matrix = Array(repeating: Array(repeating: 0, count: count2 + 1), count: count1 + 1)

        // Fill first row and column
        for i in 0...count1 {
            matrix[i][0] = i
        }
        for j in 0...count2 {
            matrix[0][j] = j
        }

        // Calculate distances
        for i in 1...count1 {
            for j in 1...count2 {
                let cost = array1[i - 1] == array2[j - 1] ? 0 : 1

                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // deletion
                    matrix[i][j - 1] + 1,      // insertion
                    matrix[i - 1][j - 1] + cost // substitution
                )
            }
        }

        return matrix[count1][count2]
    }

    // MARK: - Learning from Corrections

    /// Learn from user corrections (future enhancement)
    func recordCorrection(
        original: String,
        corrected: String,
        context: ModelContext
    ) {
        logger.info("📝 Recording user correction: \(original) -> \(corrected)")
        // Future: Store corrections in a separate model for learning
    }
}

// MARK: - Translation Memory Suggestion Model

struct TranslationMemorySuggestion: Identifiable, Sendable {
    let id = UUID()
    let sourceText: String
    let translations: [DataSchema.TranslationEntry]
    let similarity: Double
    let lastUsed: Date

    var similarityPercentage: String {
        String(format: "%.0f%%", similarity * 100)
    }

    var isHighConfidence: Bool {
        similarity >= 0.9
    }

    var isMediumConfidence: Bool {
        similarity >= 0.7 && similarity < 0.9
    }

    var confidenceIcon: String {
        if isHighConfidence {
            return "checkmark.circle.fill"
        } else if isMediumConfidence {
            return "checkmark.circle"
        } else {
            return "questionmark.circle"
        }
    }
}
