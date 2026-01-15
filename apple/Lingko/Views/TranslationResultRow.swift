//
//  TranslationResultRow.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct TranslationResultRow: View {
    let result: TranslationResult
    let audioService: AudioService
    let aiService: AIAssistantService
    let speechRate: Float

    @State private var showCopyConfirmation = false
    @State private var isAnalysisExpanded = false
    @State private var isAIEnhancedExpanded = false
    @State private var isSpeaking = false
    @State private var analysis: LinguisticAnalysis?
    @State private var service = TranslationService()
    @AppStorage("includeLinguisticAnalysis") private var includeLinguisticAnalysis: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Translation text
            Text(result.translation)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: result.layoutDirection == .rightToLeft ? .trailing : .leading)
                .environment(\.layoutDirection, result.layoutDirection)

            // Romanization (target)
            if let romanization = result.romanization {
                HStack(spacing: 6) {
                    Text(romanization)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .textSelection(.enabled)
                }
                .padding(.vertical, 4)
            }

            // Linguistic Analysis (expandable) - only show for supported languages
            if includeLinguisticAnalysis && service.supportsLinguisticAnalysis(for: result.language) {
                DisclosureGroup(
                    isExpanded: $isAnalysisExpanded,
                    content: {
                        if let analysis = analysis, analysis.hasData {
                            LinguisticAnalysisView(analysis: analysis, layoutDirection: result.layoutDirection)
                                .padding(.top, 8)
                        } else {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Analyzing...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.top, 8)
                        }
                    },
                    label: {
                        Label("Linguistic Analysis", systemImage: "brain")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                )
                .tint(.blue)
                .onChange(of: isAnalysisExpanded) { _, isExpanded in
                    if isExpanded && analysis == nil {
                        performAnalysis()
                    }
                }
            }

            // AI-Enhanced Features (expandable)
            DisclosureGroup(
                isExpanded: $isAIEnhancedExpanded,
                content: {
                    AIEnhancedView(translation: result, aiService: aiService)
                        .padding(.top, 8)
                },
                label: {
                    Label("AI Insights", systemImage: "sparkles")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
            )
            .tint(.purple)

            // Action buttons
            HStack(spacing: 20) {
                Button(
                    isSpeaking ? "Stop" : "Speak",
                    systemImage: isSpeaking ? "stop.circle.fill" : "speaker.wave.2",
                    action: toggleSpeech
                )
                .labelStyle(.iconOnly)

                Button(
                    "Copy",
                    systemImage: showCopyConfirmation ? "checkmark" : "doc.on.doc",
                    action: copyToClipboard
                )

                Spacer()
            }
            .labelStyle(.iconOnly)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .sensoryFeedback(.success, trigger: showCopyConfirmation)
    }

    // MARK: - Actions

    private func copyToClipboard() {
        #if os(iOS)
        UIPasteboard.general.string = result.translation
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result.translation, forType: .string)
        #endif

        // Show confirmation
        withAnimation {
            showCopyConfirmation = true
        }

        // Reset after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showCopyConfirmation = false
            }
        }
    }

    private func toggleSpeech() {
        if isSpeaking {
            audioService.stop()
            isSpeaking = false
        } else {
            audioService.speak(
                text: result.translation,
                language: result.language,
                rate: speechRate
            )
            isSpeaking = true

            // Monitor speech completion
            monitorSpeechCompletion()
        }
    }

    private func monitorSpeechCompletion() {
        // Poll the audio service to detect when speech finishes
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
        // Only perform analysis if the language supports it
        guard service.supportsLinguisticAnalysis(for: result.language) else {
            return
        }

        // Perform linguistic analysis on the translated text
        analysis = service.analyzeLinguistics(for: result.translation, language: result.language)
    }
}

#Preview {
    let audioService = AudioService()
    let aiService = AIAssistantService()

    return VStack(spacing: 16) {
        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "es"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "Hola, ¿cómo estás?",
                detectionConfidence: 0.95
            ),
            audioService: audioService,
            aiService: aiService,
            speechRate: 0.5
        )

        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "fr"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "Bonjour, comment allez-vous?",
                detectionConfidence: 0.65
            ),
            audioService: audioService,
            aiService: aiService,
            speechRate: 0.5
        )

        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "ja"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "こんにちは、お元気ですか？",
                detectionConfidence: 0.45
            ),
            audioService: audioService,
            aiService: aiService,
            speechRate: 0.5
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
