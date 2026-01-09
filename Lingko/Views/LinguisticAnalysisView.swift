//
//  LinguisticAnalysisView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI
import NaturalLanguage

struct LinguisticAnalysisView: View {
    let analysis: LinguisticAnalysis
    let layoutDirection: LayoutDirection

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Sentiment Section
            if let sentiment = analysis.sentiment {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Sentiment", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Image(systemName: analysis.sentimentIcon)
                            .font(.title2)
                            .foregroundStyle(analysis.sentimentColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(analysis.sentimentDescription)
                                .font(.body)
                                .fontWeight(.medium)

                            Text("Score: \(analysis.sentimentScore)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // Sentiment bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.gray.opacity(0.2))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(analysis.sentimentColor.gradient)
                                    .frame(
                                        width: geometry.size.width * CGFloat((sentiment + 1.0) / 2.0),
                                        height: 8
                                    )
                            }
                        }
                        .frame(width: 100, height: 8)
                    }
                }
            }

            // Named Entities Section
            if !analysis.entities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Named Entities", systemImage: "tag.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(analysis.entities) { entity in
                                EntityChip(entity: entity)
                            }
                        }
                    }
                }
            }

            // Tokens Section
            if !analysis.tokens.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Parts of Speech", systemImage: "text.word.spacing")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    TokenFlowLayout(tokens: analysis.tokens)
                        .environment(\.layoutDirection, layoutDirection)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Entity Chip

struct EntityChip: View {
    let entity: NamedEntity

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entity.icon)
                .font(.caption)
                .foregroundStyle(entity.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(entity.text)
                    .font(.body)
                    .fontWeight(.medium)

                Text(entity.typeDescription)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(entity.color.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Token Flow Layout

struct TokenFlowLayout: View {
    let tokens: [LinguisticToken]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tokens) { token in
                TokenChip(token: token)
            }
        }
    }
}

struct TokenChip: View {
    let token: LinguisticToken

    var body: some View {
        VStack(spacing: 4) {
            Text(token.text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            if let lemma = token.lemma, lemma != token.text {
                Text(lemma)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            Text(token.posDescription)
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(token.color.gradient)
                .clipShape(Capsule())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(token.color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}
