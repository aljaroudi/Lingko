//
//  LoadingStateView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct LoadingStateView: View {
    var style: LoadingStyle = .skeleton
    var count: Int = 3

    var body: some View {
        switch style {
        case .skeleton:
            skeletonView
        case .spinner:
            spinnerView
        case .inline:
            inlineView
        }
    }

    private var skeletonView: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonCard()
            }
        }
        .padding()
    }

    private var spinnerView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Translating...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }

    private var inlineView: some View {
        HStack(spacing: 12) {
            ProgressView()
            Text("Translating...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

struct SkeletonCard: View {
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Language header skeleton
            HStack {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 14)

                Spacer()

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(width: 60, height: 14)
            }

            // Translation text skeleton
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 16)
                    .frame(maxWidth: 200)
            }

            // Action buttons skeleton
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 32, height: 32)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.5),
                            Color.white.opacity(0)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: isAnimating ? 400 : -400)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

enum LoadingStyle {
    case skeleton
    case spinner
    case inline
}

#Preview("Skeleton") {
    LoadingStateView(style: .skeleton, count: 3)
        .background(Color(.systemGroupedBackground))
}

#Preview("Spinner") {
    LoadingStateView(style: .spinner)
}

#Preview("Inline") {
    LoadingStateView(style: .inline)
        .background(Color(.systemGroupedBackground))
}
