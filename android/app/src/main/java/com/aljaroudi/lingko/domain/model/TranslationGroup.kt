package com.aljaroudi.lingko.domain.model

data class TranslationGroup(
    val groupId: String,
    val timestamp: Long,
    val sourceText: String,
    val sourceLanguage: Language?,
    val translations: List<GroupedTranslationItem>,
    val isFavorite: Boolean,
    val tags: List<Tag> = emptyList()
)

data class GroupedTranslationItem(
    val targetLanguage: Language,
    val translatedText: String,
    val romanization: String?
)
