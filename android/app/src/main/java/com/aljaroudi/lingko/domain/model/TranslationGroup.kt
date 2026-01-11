package com.aljaroudi.lingko.domain.model

data class TranslationGroup(
    val groupId: String,
    val timestamp: Long,
    val sourceText: String,
    val sourceLanguage: Language?,
    val translations: List<GroupedTranslationItem>,
    val isFavorite: Boolean
)

data class GroupedTranslationItem(
    val targetLanguage: Language,
    val translatedText: String,
    val romanization: String?
)
