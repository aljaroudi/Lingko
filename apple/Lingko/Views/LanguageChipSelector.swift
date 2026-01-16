//
//  LanguageChipSelector.swift
//  Lingko
//
//  Created by Claude on 1/16/26.
//

import SwiftUI

struct LanguageChipSelector: View {
    let languages: [Locale.Language]
    @Binding var selectedLanguage: Locale.Language?
    let showAutoOption: Bool
    let showAddButton: Bool
    let onAddTapped: (() -> Void)?

    init(
        languages: [Locale.Language],
        selectedLanguage: Binding<Locale.Language?>,
        showAutoOption: Bool = false,
        showAddButton: Bool = false,
        onAddTapped: (() -> Void)? = nil
    ) {
        self.languages = languages
        self._selectedLanguage = selectedLanguage
        self.showAutoOption = showAutoOption
        self.showAddButton = showAddButton
        self.onAddTapped = onAddTapped
    }

    var body: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // Auto option (for source language)
                    if showAutoOption {
                        LanguageChip(
                            flag: "🌐",
                            name: "Auto",
                            isSelected: selectedLanguage == nil,
                            action: {
                                selectedLanguage = nil
                            }
                        )
                    }

                    // Language chips
                    ForEach(languages, id: \.minimalIdentifier) { language in
                        LanguageChip(
                            flag: flagEmoji(for: language),
                            name: localizedName(for: language),
                            isSelected: selectedLanguage?.minimalIdentifier == language.minimalIdentifier,
                            action: {
                                selectedLanguage = language
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }

            // Add button (iOS only, for downloading more languages)
            if showAddButton {
                Button {
                    onAddTapped?()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .padding(.trailing, 16)
                .padding(.leading, 8)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helper Methods

    private func localizedName(for language: Locale.Language) -> String {
        return SupportedLanguages.displayName(for: language)
    }

    private func flagEmoji(for language: Locale.Language) -> String {
        let code = language.minimalIdentifier
        let countryCode: String

        switch code {
        case "en": countryCode = "GB"
        case "es": countryCode = "ES"
        case "fr": countryCode = "FR"
        case "de": countryCode = "DE"
        case "zh-Hans": countryCode = "CN"
        case "zh-Hant": countryCode = "TW"
        case "ja": countryCode = "JP"
        case "ko": countryCode = "KR"
        case "ar": countryCode = "SA"
        case "ru": countryCode = "RU"
        case "hi": countryCode = "IN"
        case "pt-BR": countryCode = "BR"
        case "it": countryCode = "IT"
        case "nl": countryCode = "NL"
        case "pl": countryCode = "PL"
        case "tr": countryCode = "TR"
        case "id": countryCode = "ID"
        case "th": countryCode = "TH"
        case "uk": countryCode = "UA"
        case "vi": countryCode = "VN"
        case "cs": countryCode = "CZ"
        case "da": countryCode = "DK"
        case "fi": countryCode = "FI"
        case "el": countryCode = "GR"
        case "he": countryCode = "IL"
        case "hu": countryCode = "HU"
        case "no": countryCode = "NO"
        case "ro": countryCode = "RO"
        case "sv": countryCode = "SE"
        case "bn": countryCode = "BD"
        case "ms": countryCode = "MY"
        case "ta": countryCode = "IN"
        case "te": countryCode = "IN"
        default: return "🌐"
        }

        return countryCode.unicodeScalars.map { scalar in
            String(UnicodeScalar(127397 + scalar.value)!)
        }.joined()
    }
}

// MARK: - Language Chip Component

private struct LanguageChip: View {
    let flag: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(flag)
                    .font(.body)
                Text(name)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Source language selector with Auto
        LanguageChipSelector(
            languages: [
                Locale.Language(identifier: "en"),
                Locale.Language(identifier: "es"),
                Locale.Language(identifier: "fr"),
                Locale.Language(identifier: "de")
            ],
            selectedLanguage: .constant(nil),
            showAutoOption: true
        )

        // Target language selector with add button
        LanguageChipSelector(
            languages: [
                Locale.Language(identifier: "en"),
                Locale.Language(identifier: "es"),
                Locale.Language(identifier: "fr"),
                Locale.Language(identifier: "de")
            ],
            selectedLanguage: .constant(Locale.Language(identifier: "es")),
            showAutoOption: false,
            showAddButton: true,
            onAddTapped: { print("Add tapped") }
        )
    }
}
