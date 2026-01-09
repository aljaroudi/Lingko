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
    let speechRate: Float

    @State private var showCopyConfirmation = false
    @State private var isAnalysisExpanded = false
    @State private var isSpeaking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Language name + confidence
            HStack {
                Text(result.languageName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                confidenceIndicator
            }

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

            // Linguistic Analysis (expandable)
            if let analysis = result.linguisticAnalysis, analysis.hasData {
                DisclosureGroup(
                    isExpanded: $isAnalysisExpanded,
                    content: {
                        LinguisticAnalysisView(analysis: analysis, layoutDirection: result.layoutDirection)
                            .padding(.top, 8)
                    },
                    label: {
                        Label("Linguistic Analysis", systemImage: "brain")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                )
                .tint(.blue)
            }

            // Action buttons
            HStack(spacing: 16) {
                Button {
                    toggleSpeech()
                } label: {
                    Label(
                        isSpeaking ? "Stop" : "Speak",
                        systemImage: isSpeaking ? "stop.circle.fill" : "speaker.wave.2"
                    )
                    .font(.footnote)
                    .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    copyToClipboard()
                } label: {
                    Label("Copy", systemImage: showCopyConfirmation ? "checkmark" : "doc.on.doc")
                        .font(.footnote)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Confidence Indicator

    @ViewBuilder
    private var confidenceIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: confidenceIcon)
                .font(.caption2)
            Text(result.confidencePercentage)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(confidenceColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(confidenceColor.opacity(0.15))
        .clipShape(Capsule())
    }

    private var confidenceIcon: String {
        switch result.detectionConfidence {
        case 0.8...1.0: return "checkmark.circle.fill"
        case 0.5..<0.8: return "exclamationmark.circle.fill"
        default: return "questionmark.circle.fill"
        }
    }

    private var confidenceColor: Color {
        switch result.detectionConfidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .orange
        default: return .red
        }
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
}

#Preview {
    let audioService = AudioService()

    return VStack(spacing: 16) {
        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "es"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "Hola, ¿cómo estás?",
                detectionConfidence: 0.95
            ),
            audioService: audioService,
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
            speechRate: 0.5
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
