package com.aljaroudi.lingko.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.SavedTranslation
import java.util.UUID

@Entity(tableName = "translations")
data class SavedTranslationEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val groupId: String,
    val timestamp: Long,
    val sourceText: String,
    val sourceLanguage: String?,
    val targetLanguage: String,
    val translatedText: String,
    val romanization: String?,
    val isFavorite: Boolean = false
) {
    fun toDomain() = SavedTranslation(
        id = id,
        timestamp = timestamp,
        sourceText = sourceText,
        sourceLanguage = sourceLanguage?.let { Language.fromCode(it) },
        targetLanguage = Language.fromCode(targetLanguage)!!,
        translatedText = translatedText,
        romanization = romanization,
        isFavorite = isFavorite
    )
}
