package com.aljaroudi.lingko.ui.translation

import com.aljaroudi.lingko.domain.model.DetectedLanguage
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.TranslationResult

data class TranslationUiState(
    val inputText: String = "",
    val sourceLanguage: DetectedLanguage? = null,
    val selectedTargetLanguages: Set<Language> = setOf(
        Language.SPANISH,
        Language.FRENCH,
        Language.GERMAN
    ),
    val translations: List<TranslationResult> = emptyList(),
    val isTranslating: Boolean = false,
    val error: String? = null
)
