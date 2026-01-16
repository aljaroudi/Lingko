//
//  AIEnhancedView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

/// View for displaying AI-enhanced translation features
///
/// Shows example sentences, alternative translations, formality levels,
/// cultural notes, and provides an interface to ask questions about translations.
struct AIEnhancedView: View {
    let translation: TranslationResult
    let aiService: AIAssistantService

    @State private var isExamplesExpanded = false
    @State private var isAlternativesExpanded = false
    @State private var isCulturalNotesExpanded = false
    @State private var showQuestionDialog = false

    @State private var isLoadingExamples = false
    @State private var isLoadingAlternatives = false
    @State private var isLoadingCulturalNotes = false

    @State private var exampleSentences: [String] = []
    @State private var alternatives: [Alternative] = []
    @State private var culturalNotes: String?
    @State private var question = ""
    @State private var answer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Formality Level Indicator
            if let formality = translation.formalityLevel {
                formalityIndicator(formality)
            }

            // Example Sentences
            if aiService.isAvailable {
                examplesSection
            }

            // Alternative Translations
            if aiService.isAvailable {
                alternativesSection
            }

            // Cultural Notes
            if aiService.isAvailable {
                culturalNotesSection
            }

            // Ask About Translation
//            if aiService.isAvailable {
//                askQuestionButton
//            }
        }
        .onChange(of: translation.id) { _, _ in
            // Reset all AI state when translation changes
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
                                Text("\(index + 1).")
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
        .background(Color(.tertiarySystemGroupedBackground))
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

    // MARK: - Ask Question Button

    @ViewBuilder
    private var askQuestionButton: some View {
        Button {
            showQuestionDialog = true
        } label: {
            Label("Ask About This Translation", systemImage: "questionmark.bubble")
                .font(.caption)
                .fontWeight(.medium)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .sheet(isPresented: $showQuestionDialog) {
            questionDialog
        }
    }

    @ViewBuilder
    private var questionDialog: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Ask about: \"\(translation.translation)\"")
                    .font(.headline)
                    .padding(.bottom, 8)

                TextField("Enter your question", text: $question, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3...6)

                Button {
                    Task {
                        await askQuestion()
                    }
                } label: {
                    Label("Ask", systemImage: "paperplane")
                }
                .buttonStyle(.borderedProminent)
                .disabled(question.isEmpty)

                if let answer = answer {
                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Answer", systemImage: "lightbulb")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(answer)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Ask a Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showQuestionDialog = false
                        question = ""
                        answer = nil
                    }
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

    private func askQuestion() async {
        guard !question.isEmpty else { return }

        answer = await aiService.askAboutTranslation(
            question: question,
            translation: translation.translation,
            language: translation.language
        )
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
            .background(Color(.secondarySystemGroupedBackground))
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
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
