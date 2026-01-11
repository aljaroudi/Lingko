package com.aljaroudi.lingko.data.repository

import com.aljaroudi.lingko.data.local.SavedTranslationEntity
import com.aljaroudi.lingko.data.local.TranslationHistoryDao
import com.aljaroudi.lingko.domain.model.GroupedTranslationItem
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.TranslationGroup
import com.aljaroudi.lingko.domain.model.TranslationResult
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class HistoryRepository @Inject constructor(
    private val dao: TranslationHistoryDao,
    private val tagRepository: TagRepository
) {
    fun getRecentTranslations(limit: Int = 100): Flow<List<TranslationGroup>> {
        return dao.getRecentTranslations(limit).map { entities ->
            groupEntities(entities)
        }
    }

    fun searchTranslations(query: String): Flow<List<TranslationGroup>> {
        return dao.searchTranslations(query).map { entities ->
            groupEntities(entities)
        }
    }

    fun getFavoriteTranslations(): Flow<List<TranslationGroup>> {
        return dao.getFavoriteTranslations().map { entities ->
            groupEntities(entities)
        }
    }

    private fun groupEntities(entities: List<SavedTranslationEntity>): List<TranslationGroup> {
        return entities
            .groupBy { it.groupId }
            .map { (groupId, groupEntities) ->
                val first = groupEntities.first()
                // Tags will be empty for now - we'll fetch them separately when needed
                TranslationGroup(
                    groupId = groupId,
                    timestamp = first.timestamp,
                    sourceText = first.sourceText,
                    sourceLanguage = first.sourceLanguage?.let { Language.fromCode(it) },
                    translations = groupEntities.map { entity ->
                        GroupedTranslationItem(
                            targetLanguage = Language.fromCode(entity.targetLanguage)!!,
                            translatedText = entity.translatedText,
                            romanization = entity.romanization
                        )
                    },
                    isFavorite = groupEntities.any { it.isFavorite },
                    tags = emptyList() // Tags loaded separately in ViewModel
                )
            }
            .sortedByDescending { it.timestamp }
    }

    suspend fun saveTranslations(
        translations: List<TranslationResult>,
        sourceText: String,
        groupId: String
    ) {
        val timestamp = System.currentTimeMillis()
        val entities = translations.map { translation ->
            SavedTranslationEntity(
                groupId = groupId,
                sourceText = sourceText,
                sourceLanguage = translation.sourceLanguage?.code,
                targetLanguage = translation.language.code,
                translatedText = translation.translation,
                romanization = translation.romanization,
                timestamp = timestamp
            )
        }
        dao.insertAll(entities)
    }

    suspend fun toggleFavorite(groupId: String) {
        dao.toggleFavoriteByGroup(groupId)
    }

    suspend fun delete(groupId: String) {
        dao.deleteByGroupId(groupId)
    }

    suspend fun clearAll() {
        dao.clearAll()
    }
}
