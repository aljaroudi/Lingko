package com.aljaroudi.lingko.domain.model

data class SavedTranslation(
    val id: String,
    val timestamp: Long,
    val sourceText: String,
    val sourceLanguage: Language?,
    val targetLanguage: Language,
    val translatedText: String,
    val romanization: String?,
    val isFavorite: Boolean
)
