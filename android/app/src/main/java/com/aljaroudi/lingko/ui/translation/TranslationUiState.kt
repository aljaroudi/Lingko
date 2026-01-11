package com.aljaroudi.lingko.ui.translation

import com.aljaroudi.lingko.domain.model.DetectedLanguage
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.TranslationResult
import com.aljaroudi.lingko.util.LocaleHelper

data class TranslationUiState(
    val inputText: String = "",
    val sourceLanguage: DetectedLanguage? = null,
    val possibleSourceLanguages: List<DetectedLanguage> = emptyList(),
    val manualSourceLanguage: Language? = null,
    val selectedTargetLanguages: Set<Language> = LocaleHelper.getSmartDefaultLanguages(),
    val translations: List<TranslationResult> = emptyList(),
    val isTranslating: Boolean = false,
    val showRomanization: Boolean = true,
    val isSpeaking: Boolean = false,
    val error: String? = null
) {
    // Effective source language to use for translation (manual override or detected)
    val effectiveSourceLanguage: Language?
        get() = manualSourceLanguage ?: sourceLanguage?.language
}
