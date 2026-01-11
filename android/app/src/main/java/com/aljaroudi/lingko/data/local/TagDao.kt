package com.aljaroudi.lingko.data.local

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface TagDao {
    @Query("SELECT * FROM tags ORDER BY sortOrder ASC, name ASC")
    fun getAllTags(): Flow<List<TagEntity>>
    
    @Query("SELECT * FROM tags WHERE id = :tagId")
    suspend fun getTagById(tagId: String): TagEntity?
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTag(tag: TagEntity)
    
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertTags(tags: List<TagEntity>)
    
    @Insert(onConflict = OnConflictStrategy.IGNORE)
    suspend fun insertTranslationTagCrossRef(crossRef: TranslationTagCrossRef)
    
    @Query("DELETE FROM translation_tags WHERE translationGroupId = :groupId")
    suspend fun deleteAllTagsForTranslation(groupId: String)
    
    @Query("SELECT * FROM tags WHERE id IN (SELECT tagId FROM translation_tags WHERE translationGroupId = :groupId) ORDER BY sortOrder ASC, name ASC")
    suspend fun getTagsForTranslationSync(groupId: String): List<TagEntity>
    
    @Query("SELECT COUNT(*) FROM tags")
    suspend fun getTagCount(): Int
}
