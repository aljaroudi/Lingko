package com.aljaroudi.lingko.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import kotlinx.coroutines.flow.Flow

@Dao
interface TranslationHistoryDao {
    @Query("""
        SELECT * FROM translations
        WHERE groupId IN (
            SELECT DISTINCT groupId FROM translations
            ORDER BY timestamp DESC
            LIMIT :limit
        )
        ORDER BY timestamp DESC, targetLanguage ASC
    """)
    fun getRecentTranslations(limit: Int): Flow<List<SavedTranslationEntity>>

    @Query("""
        SELECT * FROM translations
        WHERE (sourceText LIKE '%' || :query || '%' OR translatedText LIKE '%' || :query || '%')
        ORDER BY timestamp DESC, targetLanguage ASC
    """)
    fun searchTranslations(query: String): Flow<List<SavedTranslationEntity>>

    @Query("""
        SELECT * FROM translations
        WHERE isFavorite = 1
        ORDER BY timestamp DESC, targetLanguage ASC
    """)
    fun getFavoriteTranslations(): Flow<List<SavedTranslationEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertAll(translations: List<SavedTranslationEntity>)

    @Query("UPDATE translations SET isFavorite = NOT isFavorite WHERE groupId = :groupId")
    suspend fun toggleFavoriteByGroup(groupId: String)

    @Query("DELETE FROM translations WHERE groupId = :groupId")
    suspend fun deleteByGroupId(groupId: String)

    @Query("DELETE FROM translations")
    suspend fun clearAll()
}
