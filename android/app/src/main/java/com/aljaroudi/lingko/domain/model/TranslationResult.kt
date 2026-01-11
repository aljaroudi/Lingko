package com.aljaroudi.lingko.domain.model

import java.util.UUID

data class TranslationResult(
    val id: String = UUID.randomUUID().toString(),
    val language: Language,
    val sourceLanguage: Language?,
    val translation: String,
    val detectionConfidence: Float,
    val timestamp: Long = System.currentTimeMillis()
)
