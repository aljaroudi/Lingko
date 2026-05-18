//
//  AIEnhancedView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct AIEnhancedView: View {
    let translation: TranslationResult
    let aiService: AIAssistantService

    @State private var isExamplesExpanded = false
    @State private var isAlternativesExpanded = false
    @State private var isCulturalNotesExpanded = false

    @State private var isLoadingExamples = false
    @State private var isLoadingAlternatives = false
    @State private var isLoadingCulturalNotes = false

    @State private var exampleSentences: [String] = []
    @State private var alternatives: [Alternative] = []
    @State private var culturalNotes: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let formality = translation.formalityLevel {
                formalityIndicator(formality)
            }

            if aiService.isAvailable {
                examplesSection
            }

            if aiService.isAvailable {
                alternativesSection
            }

            if aiService.isAvailable {
                culturalNotesSection
            }
        }
        .onChange(of: translation.id) { _, _ in
            exampleSentences = []
            alternatives = []
            culturalNotes = nil
            isExamplesExpanded = false
            isAlternativesExpanded = false
            isCulturalNotesExpanded = false
        }
    }

    // MARK: - Formality Indicator

    @ViewBuilder
    private func formalityIndicator(_ formality: FormalityLevel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: formality.icon)
                .font(.caption)
            Text(formality.description)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Examples Section

    @ViewBuilder
    private var examplesSection: some View {
        DisclosureGroup(
            isExpanded: $isExamplesExpanded,
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    if isLoadingExamples {
                        ProgressView()
                            .padding(.vertical, 8)
                    } else if exampleSentences.isEmpty {
                        Text("No examples available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(exampleSentences.enumerated()), id: \.offset) { index, sentence in
                            HStack(alignment: .top, spacing: 8) {
                                Text(index + 1, format: .number)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(sentence)
                                    .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .padding(.top, 8)
            },
            label: {
                Label("Example Sentences", systemImage: "text.bubble")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        )
        .tint(.blue)
        .onChange(of: isExamplesExpanded) { _, isExpanded in
            if isExpanded && exampleSentences.isEmpty && !isLoadingExamples {
                Task {
                    await loadExamples()
                }
            }
        }
    }

    // MARK: - Alternatives Section

    @ViewBuilder
    private var alternativesSection: some View {
        DisclosureGroup(
            isExpanded: $isAlternativesExpanded,
            content: {
                VStack(alignment: .leading, spacing: 12) {
                    if isLoadingAlternatives {
                        ProgressView()
                            .padding(.vertical, 8)
                    } else if alternatives.isEmpty {
                        Text("No alternatives available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(alternatives) { alternative in
                            alternativeCard(alternative)
                        }
                    }
                }
                .padding(.top, 8)
            },
            label: {
                Label("Alternative Translations", systemImage: "arrow.triangle.branch")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        )
        .tint(.blue)
        .onChange(of: isAlternativesExpanded) { _, isExpanded in
            if isExpanded && alternatives.isEmpty && !isLoadingAlternatives {
                Task {
                    await loadAlternatives()
                }
            }
        }
    }

    @ViewBuilder
    private func alternativeCard(_ alternative: Alternative) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(alternative.text)
                    .font(.callout)
                    .fontWeight(.medium)

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: alternative.formalityLevel.icon)
                        .font(.caption2)
                    Text(alternative.formalityLevel.description)
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            }

            Text(alternative.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        #if os(iOS)
        .background(Color(.tertiarySystemGroupedBackground))
        #elseif os(macOS)
        .background(Color.secondary.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Cultural Notes Section

    @ViewBuilder
    private var culturalNotesSection: some View {
        DisclosureGroup(
            isExpanded: $isCulturalNotesExpanded,
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    if isLoadingCulturalNotes {
                        ProgressView()
                            .padding(.vertical, 8)
                    } else if let notes = culturalNotes {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        Text("No cultural notes available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    }
                }
                .padding(.top, 8)
            },
            label: {
                Label("Cultural Context", systemImage: "globe.asia.australia")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
        )
        .tint(.blue)
        .onChange(of: isCulturalNotesExpanded) { _, isExpanded in
            if isExpanded && culturalNotes == nil && !isLoadingCulturalNotes {
                Task {
                    await loadCulturalNotes()
                }
            }
        }
    }

    // MARK: - Actions

    private func loadExamples() async {
        isLoadingExamples = true
        exampleSentences = await aiService.generateExamples(
            for: translation.translation,
            in: translation.language
        )
        isLoadingExamples = false
    }

    private func loadAlternatives() async {
        isLoadingAlternatives = true
        alternatives = await aiService.getAlternatives(
            for: translation.translation,
            from: translation.sourceLanguage,
            to: translation.language
        )
        isLoadingAlternatives = false
    }

    private func loadCulturalNotes() async {
        isLoadingCulturalNotes = true
        culturalNotes = await aiService.getCulturalNotes(
            for: translation.translation,
            in: translation.language
        )
        isLoadingCulturalNotes = false
    }

}

#Preview {
    let aiService = AIAssistantService()

    return ScrollView {
        VStack(spacing: 16) {
            AIEnhancedView(
                translation: TranslationResult(
                    language: Locale.Language(identifier: "es"),
                    sourceLanguage: Locale.Language(identifier: "en"),
                    translation: "Hola, ¿cómo estás?",
                    detectionConfidence: 0.95,
                    formalityLevel: .informal
                ),
                aiService: aiService
            )
            .padding()
            .background(Color.platformSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            AIEnhancedView(
                translation: TranslationResult(
                    language: Locale.Language(identifier: "ja"),
                    sourceLanguage: Locale.Language(identifier: "en"),
                    translation: "おはようございます",
                    detectionConfidence: 0.92,
                    formalityLevel: .formal
                ),
                aiService: aiService
            )
            .padding()
            .background(Color.platformSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    .background(Color.platformGroupedBackground)
}
