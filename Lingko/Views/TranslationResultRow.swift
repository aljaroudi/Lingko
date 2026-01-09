//
//  TranslationResultRow.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct TranslationResultRow: View {
    let result: TranslationResult
    @State private var showCopyConfirmation = false
    @State private var isAnalysisExpanded = false

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
}

#Preview {
    VStack(spacing: 16) {
        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "es"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "Hola, ¿cómo estás?",
                detectionConfidence: 0.95
            )
        )

        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "fr"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "Bonjour, comment allez-vous?",
                detectionConfidence: 0.65
            )
        )

        TranslationResultRow(
            result: TranslationResult(
                language: Locale.Language(identifier: "ja"),
                sourceLanguage: Locale.Language(identifier: "en"),
                translation: "こんにちは、お元気ですか？",
                detectionConfidence: 0.45
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
