//
//  EmptyStateView.swift
//  Lingko
//
//  Created by Mohammed on 1/9/26.
//

import SwiftUI

struct EmptyStateView: View {
    let configuration: EmptyStateConfiguration

    var body: some View {
        VStack(spacing: 20) {
            // Icon
            Image(systemName: configuration.iconName)
                .font(.system(size: 60))
                .foregroundStyle(configuration.iconColor.gradient)
                .symbolEffect(.bounce, value: configuration.id)

            // Title and message
            VStack(spacing: 8) {
                Text(configuration.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text(configuration.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            // Action button
            if let action = configuration.action {
                Button {
                    action.handler()
                } label: {
                    Label(action.title, systemImage: action.iconName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
}

struct EmptyStateConfiguration: Identifiable {
    let id = UUID()
    let iconName: String
    let iconColor: Color
    let title: String
    let message: String
    let action: EmptyStateAction?

    init(
        iconName: String,
        iconColor: Color = .blue,
        title: String,
        message: String,
        action: EmptyStateAction? = nil
    ) {
        self.iconName = iconName
        self.iconColor = iconColor
        self.title = title
        self.message = message
        self.action = action
    }

    // Predefined configurations
    static let translationEmpty = EmptyStateConfiguration(
        iconName: "character.bubble",
        iconColor: .blue,
        title: "Ready to translate",
        message: "Enter text above to translate into multiple languages simultaneously"
    )

    static let historyEmpty = EmptyStateConfiguration(
        iconName: "clock",
        iconColor: .orange,
        title: "No translation history",
        message: "Your saved translations will appear here"
    )

    static func searchEmpty(query: String) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "magnifyingglass",
            iconColor: .gray,
            title: "No results found",
            message: "No translations match \"\(query)\""
        )
    }

    static func noLanguagesSelected(action: @escaping () -> Void) -> EmptyStateConfiguration {
        EmptyStateConfiguration(
            iconName: "globe",
            iconColor: .blue,
            title: "No languages selected",
            message: "Select target languages to start translating",
            action: EmptyStateAction(
                title: "Select Languages",
                iconName: "globe",
                handler: action
            )
        )
    }

    static let cameraEmpty = EmptyStateConfiguration(
        iconName: "camera",
        iconColor: .purple,
        title: "No text detected",
        message: "Point your camera at text or select an image to translate"
    )

    static let offlineEmpty = EmptyStateConfiguration(
        iconName: "wifi.slash",
        iconColor: .orange,
        title: "No internet connection",
        message: "Connect to download language packs for offline translation"
    )
}

struct EmptyStateAction {
    let title: String
    let iconName: String
    let handler: () -> Void
}

#Preview("Translation Empty") {
    EmptyStateView(configuration: .translationEmpty)
}

#Preview("History Empty") {
    EmptyStateView(configuration: .historyEmpty)
}

#Preview("Search Empty") {
    EmptyStateView(configuration: .searchEmpty(query: "hello"))
}

#Preview("No Languages") {
    EmptyStateView(configuration: .noLanguagesSelected(action: {}))
}

#Preview("Camera Empty") {
    EmptyStateView(configuration: .cameraEmpty)
}

#Preview("Offline") {
    EmptyStateView(configuration: .offlineEmpty)
}
