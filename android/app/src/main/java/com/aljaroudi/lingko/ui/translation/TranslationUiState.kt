package com.aljaroudi.lingko.ui.translation

import com.aljaroudi.lingko.domain.model.DetectedLanguage
import com.aljaroudi.lingko.domain.model.Language

data class TranslationUiState(
    val inputText: String = "",
    val sourceLanguage: DetectedLanguage? = null,
    val selectedTargetLanguage: Language = Language.SPANISH,
    val translationResult: String? = null,
    val isTranslating: Boolean = false,
    val error: String? = null
)
