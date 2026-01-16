package com.aljaroudi.lingko.ui.translation.components

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aljaroudi.lingko.domain.model.Language

@Composable
fun LanguageChipSelector(
    languages: List<Language>,
    selectedLanguage: Language?,
    onLanguageSelected: (Language) -> Unit,
    showAutoOption: Boolean = false,
    onAutoSelected: (() -> Unit)? = null,
    isAutoSelected: Boolean = false,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState())
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        // Auto option (for source language)
        if (showAutoOption && onAutoSelected != null) {
            FilterChip(
                selected = isAutoSelected,
                onClick = onAutoSelected,
                label = {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("🌐")
                        Text("Auto")
                    }
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        }

        // Language options
        languages.forEach { language ->
            FilterChip(
                selected = selectedLanguage == language && !isAutoSelected,
                onClick = { onLanguageSelected(language) },
                label = {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(language.flagEmoji)
                        Text(language.nativeName)
                    }
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primaryContainer,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimaryContainer
                )
            )
        }
    }
}

/**
 * Extension property to get flag emoji for a language
 */
private val Language.flagEmoji: String
    get() {
        val countryCode = when (code) {
            "en" -> "GB"
            "es" -> "ES"
            "fr" -> "FR"
            "de" -> "DE"
            "zh" -> "CN"
            "ja" -> "JP"
            "ko" -> "KR"
            "ar" -> "SA"
            "ru" -> "RU"
            "hi" -> "IN"
            "pt" -> "PT"
            "it" -> "IT"
            "nl" -> "NL"
            "pl" -> "PL"
            "tr" -> "TR"
            else -> return "🌐"
        }

        return countryCode.map { char ->
            Character.codePointAt("$char", 0) - 0x41 + 0x1F1E6
        }.map { codePoint ->
            Character.toChars(codePoint)
        }.joinToString("") { String(it) }
    }
