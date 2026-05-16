//
//  AIInsightsDetailView.swift
//  Lingko
//

import SwiftUI

struct AIInsightsDetailView: View {
    let destination: HistoryAIInsightsDestination

    @State private var aiService = AIAssistantService()
    @State private var translationService = TranslationService()
    @State private var isLoadingExamples = false
    @State private var isLoadingAlternatives = false
    @State private var isLoadingCulturalNotes = false
    @State private var exampleSentences: [String] = []
    @State private var alternatives: [Alternative] = []
    @State private var culturalNotes: String?
    @State private var analysis: LinguisticAnalysis?

    private var language: Locale.Language { Locale.Language(identifier: destination.languageCode) }

    private var layoutDirection: LayoutDirection {
        Script.detect(from: language).isRTL ? .rightToLeft : .leftToRight
    }

    private var sourceLanguageName: String {
        guard let code = destination.sourceLanguageCode else { return "Detected" }
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }

    private var targetLanguageName: String {
        Locale.current.localizedString(forLanguageCode: destination.languageCode) ?? destination.languageCode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                translationCard

                if translationService.supportsLinguisticAnalysis(for: language),
                   let analysis, analysis.hasData {
                    sectionCard(title: "Linguistic Analysis", icon: "brain") {
                        LinguisticAnalysisView(analysis: analysis, layoutDirection: layoutDirection)
                    }
                }

                if aiService.isAvailable {
                    sectionCard(title: "Example Sentences", icon: "text.bubble") {
                        examplesContent
                    }
                    sectionCard(title: "Alternative Translations", icon: "arrow.triangle.branch") {
                        alternativesContent
                    }
                    sectionCard(title: "Cultural Context", icon: "globe.asia.australia") {
                        culturalNotesContent
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task { await loadAll() }
    }

    // MARK: - Translation Card

    @ViewBuilder
    private var translationCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sourceLanguageName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(destination.sourceText)
                        .font(.title2.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }
            .padding()

            Divider()

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(targetLanguageName)
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                    Text(destination.translationText)
                        .font(.title2)
                        .foregroundStyle(.accent)
                        .frame(maxWidth: .infinity, alignment: layoutDirection == .rightToLeft ? .trailing : .leading)
                        .environment(\.layoutDirection, layoutDirection)
                        .textSelection(.enabled)
                    if let romanization = destination.romanization {
                        Text(romanization)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .textSelection(.enabled)
                    }
                }
            }
            .padding()
        }
        #if os(iOS)
        .background(Color(.secondarySystemGroupedBackground))
        #else
        .background(Color.secondary.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Section Card

    @ViewBuilder
    private func sectionCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        #if os(iOS)
        .background(Color(.secondarySystemGroupedBackground))
        #else
        .background(Color.secondary.opacity(0.1))
        #endif
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Content Views

    @ViewBuilder
    private var examplesContent: some View {
        if isLoadingExamples {
            ProgressView()
        } else if exampleSentences.isEmpty {
            Text("No examples available").font(.callout).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(exampleSentences.enumerated()), id: \.offset) { index, sentence in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.callout).foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        Text(sentence).font(.callout)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var alternativesContent: some View {
        if isLoadingAlternatives {
            ProgressView()
        } else if alternatives.isEmpty {
            Text("No alternatives available").font(.callout).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(alternatives) { alternative in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(alternative.text).font(.callout).fontWeight(.medium)
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: alternative.formalityLevel.icon).font(.caption2)
                                Text(alternative.formalityLevel.description).font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }
                        Text(alternative.explanation).font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(10)
                    #if os(iOS)
                    .background(Color(.tertiarySystemGroupedBackground))
                    #else
                    .background(Color.secondary.opacity(0.08))
                    #endif
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    @ViewBuilder
    private var culturalNotesContent: some View {
        if isLoadingCulturalNotes {
            ProgressView()
        } else if let notes = culturalNotes {
            Text(notes).font(.callout).foregroundStyle(.secondary)
        } else {
            Text("No cultural notes available").font(.callout).foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading

    private func loadAll() async {
        if translationService.supportsLinguisticAnalysis(for: language) {
            analysis = translationService.analyzeLinguistics(for: destination.translationText, language: language)
        }

        let result = TranslationResult(
            language: language,
            sourceLanguage: destination.sourceLanguageCode.map { Locale.Language(identifier: $0) },
            translation: destination.translationText,
            detectionConfidence: destination.detectionConfidence,
            romanization: destination.romanization
        )

        async let examples: Void = loadExamples(result)
        async let alts: Void = loadAlternatives(result)
        async let cultural: Void = loadCulturalNotes(result)
        _ = await (examples, alts, cultural)
    }

    private func loadExamples(_ result: TranslationResult) async {
        isLoadingExamples = true
        exampleSentences = await aiService.generateExamples(for: result.translation, in: result.language)
        isLoadingExamples = false
    }

    private func loadAlternatives(_ result: TranslationResult) async {
        isLoadingAlternatives = true
        alternatives = await aiService.getAlternatives(for: result.translation, from: result.sourceLanguage, to: result.language)
        isLoadingAlternatives = false
    }

    private func loadCulturalNotes(_ result: TranslationResult) async {
        isLoadingCulturalNotes = true
        culturalNotes = await aiService.getCulturalNotes(for: result.translation, in: result.language)
        isLoadingCulturalNotes = false
    }
}
