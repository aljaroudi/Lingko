//
//  ErrorBannerView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct ErrorBannerView: View {
    let error: ErrorMessage
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void

    init(error: ErrorMessage, onRetry: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.error = error
        self.onRetry = onRetry
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 12) {
            // Error icon
            Image(systemName: error.severity.iconName)
                .font(.title2)
                .foregroundStyle(error.severity.color)

            // Error content
            VStack(alignment: .leading, spacing: 4) {
                Text(error.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                if let message = error.message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: 8) {
                if let action = error.action, let actionTitle = error.actionTitle {
                    Button {
                        action()
                    } label: {
                        Text(actionTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if let onRetry = onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Text("Retry")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(error.severity.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct ErrorMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String?
    let severity: ErrorSeverity
    let actionTitle: String?
    let action: (() -> Void)?

    init(title: String, message: String? = nil, severity: ErrorSeverity = .error, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.title = title
        self.message = message
        self.severity = severity
        self.actionTitle = actionTitle
        self.action = action
    }

    static func from(_ error: Error) -> ErrorMessage {
        if let translationError = error as? TranslationError {
            // Handle missing language packs specially
            if case .missingLanguagePacks = translationError {
                return ErrorMessage(
                    title: translationError.errorDescription ?? "Language packs missing",
                    message: translationError.recoverySuggestion,
                    severity: .warning,
                    actionTitle: "Download",
                    action: {
                        openTranslateSettings()
                    }
                )
            }

            return ErrorMessage(
                title: translationError.errorDescription ?? "Translation failed",
                message: translationError.recoverySuggestion,
                severity: .error
            )
        } else {
            return ErrorMessage(
                title: "Something went wrong",
                message: error.localizedDescription,
                severity: .error
            )
        }
    }

    private static func openTranslateSettings() {
        // Try to open iOS Translate settings
        if let url = URL(string: "App-prefs:TRANSLATE") {
            UIApplication.shared.open(url) { success in
                if !success {
                    // Fallback to general Settings if Translate-specific URL doesn't work
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
        }
    }

    static func offline() -> ErrorMessage {
        ErrorMessage(
            title: "No internet connection",
            message: "Some features may not be available",
            severity: .warning
        )
    }

    static func languagePackNeeded(language: String) -> ErrorMessage {
        ErrorMessage(
            title: "Language pack required",
            message: "Download \(language) to translate offline",
            severity: .info
        )
    }
}

enum ErrorSeverity {
    case error
    case warning
    case info

    var color: Color {
        switch self {
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    var backgroundColor: Color {
        switch self {
        case .error: return Color.red.opacity(0.1)
        case .warning: return Color.orange.opacity(0.1)
        case .info: return Color.blue.opacity(0.1)
        }
    }

    var iconName: String {
        switch self {
        case .error: return "exclamationmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
}

// View modifier for easy error banner display
struct ErrorBannerModifier: ViewModifier {
    @Binding var error: ErrorMessage?
    var onRetry: (() -> Void)?

    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let error = error {
                ErrorBannerView(
                    error: error,
                    onRetry: onRetry,
                    onDismiss: {
                        withAnimation {
                            self.error = nil
                        }
                    }
                )
                .padding(.top, 8)
                .zIndex(999)
            }
        }
    }
}

extension View {
    func errorBanner(_ error: Binding<ErrorMessage?>, onRetry: (() -> Void)? = nil) -> some View {
        modifier(ErrorBannerModifier(error: error, onRetry: onRetry))
    }
}

#Preview("Error") {
    VStack {
        ErrorBannerView(
            error: ErrorMessage(
                title: "Translation failed",
                message: "Unable to connect to translation service",
                severity: .error
            ),
            onRetry: {},
            onDismiss: {}
        )
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Warning") {
    VStack {
        ErrorBannerView(
            error: ErrorMessage.offline(),
            onDismiss: {}
        )
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Info") {
    VStack {
        ErrorBannerView(
            error: ErrorMessage.languagePackNeeded(language: "Spanish"),
            onDismiss: {}
        )
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
