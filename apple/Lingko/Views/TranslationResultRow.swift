//
//  TranslationResultRow.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct TranslationResultRow: View {
    let result: TranslationResult
    let sourceText: String
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void
    var onLoad: (() -> Void)? = nil

    @State private var showCopyConfirmation = false
    @State private var isAnalysisExpanded = false
    @State private var isAIEnhancedExpanded = false
    @State private var isSpeaking = false
    @State private var analysis: LinguisticAnalysis?
    @State private var translationService = TranslationService()
    @State private var audioService = AudioService()
    @State private var aiService = AIAssistantService()
    @AppStorage("defaultSpeechRate") private var speechRate: Double = 0.5
    @AppStorage("includeLinguisticAnalysis") private var includeLinguisticAnalysis: Bool = true

    private var sourceLangName: String {
        guard let sourceLang = result.sourceLanguage else { return "" }
        return Locale.current.localizedString(forLanguageCode: sourceLang.minimalIdentifier) ?? sourceLang.minimalIdentifier
    }

    private var targetLangName: String {
        Locale.current.localizedString(forLanguageCode: result.language.minimalIdentifier) ?? result.language.minimalIdentifier
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sourceSection
            Divider()
            targetSection
        }
        .onChange(of: result.id) { _, _ in analysis = nil }
        .sensoryFeedback(.success, trigger: showCopyConfirmation)
    }

    @ViewBuilder
    private var sourceSection: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(sourceLangName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(sourceText)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Image(systemName: "play.circle.fill")
                .font(.title2)
                .foregroundStyle(.primary.opacity(0.3))
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture { onLoad?() }
    }

    @ViewBuilder
    private var targetSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(targetLangName)
                        .font(.subheadline)
                        .foregroundStyle(.accent)
                    Text(result.translation)
                        .font(.title2)
                        .foregroundStyle(.accent)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: result.layoutDirection == .rightToLeft ? .trailing : .leading)
                        .environment(\.layoutDirection, result.layoutDirection)
                    if let romanization = result.romanization {
                        Text(romanization)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                            .textSelection(.enabled)
                    }
                }
                Button(action: toggleSpeech) {
                    Image(systemName: isSpeaking ? "stop.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isSpeaking ? "Stop speaking" : "Speak translation")
            }

            HStack(spacing: 20) {
                Button(action: onFavoriteToggle) {
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .foregroundStyle(isFavorite ? Color.yellow : Color.accentColor)
                }
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button(action: copyToClipboard) {
                    Image(systemName: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(.accent)
                }
                .accessibilityLabel(showCopyConfirmation ? "Copied" : "Copy translation")

                Spacer(minLength: 0)
            }
            .buttonStyle(.plain)
            .font(.title3)

            if includeLinguisticAnalysis && translationService.supportsLinguisticAnalysis(for: result.language) {
                DisclosureGroup(isExpanded: $isAnalysisExpanded) {
                    if let analysis, analysis.hasData {
                        LinguisticAnalysisView(analysis: analysis, layoutDirection: result.layoutDirection)
                            .padding(.top, 6)
                    } else {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Analyzing...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 6)
                    }
                } label: {
                    Label("Linguistic Analysis", systemImage: "brain")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .tint(.accentColor)
                .onChange(of: isAnalysisExpanded) { _, isExpanded in
                    if isExpanded && analysis == nil { performAnalysis() }
                }
            }

            DisclosureGroup(isExpanded: $isAIEnhancedExpanded) {
                AIEnhancedView(translation: result, aiService: aiService)
                    .padding(.top, 6)
            } label: {
                Label("AI Insights", systemImage: "sparkles")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .tint(.accentColor)
        }
        .padding()
    }

    private func copyToClipboard() {
        PlatformUtils.copyToPasteboard(result.translation)
        withAnimation { showCopyConfirmation = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopyConfirmation = false }
        }
    }

    private func toggleSpeech() {
        if isSpeaking {
            audioService.stop()
            isSpeaking = false
        } else {
            audioService.speak(text: result.translation, language: result.language, rate: Float(speechRate))
            isSpeaking = true
            monitorSpeechCompletion()
        }
    }

    private func monitorSpeechCompletion() {
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            while isSpeaking && audioService.isPlaying {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if isSpeaking && !audioService.isPlaying {
                isSpeaking = false
            }
        }
    }

    private func performAnalysis() {
        guard translationService.supportsLinguisticAnalysis(for: result.language) else { return }
        analysis = translationService.analyzeLinguistics(for: result.translation, language: result.language)
    }
}

#Preview {
    List {
        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "ru"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "Привет, мир!",
                detectionConfidence: 0.95
            ),
            sourceText: "Hello, world!",
            isFavorite: false,
            onFavoriteToggle: {}
        )

        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "ja"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "こんにちは、お元気ですか？",
                detectionConfidence: 0.45,
                romanization: "Konnichiwa, ogenki desu ka?"
            ),
            sourceText: "Hello, how are you?",
            isFavorite: true,
            onFavoriteToggle: {}
        )
    }
}
