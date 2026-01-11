package com.aljaroudi.lingko.data.repository

import com.aljaroudi.lingko.data.local.TagDao
import com.aljaroudi.lingko.data.local.TagEntity
import com.aljaroudi.lingko.data.local.TranslationTagCrossRef
import com.aljaroudi.lingko.domain.model.Tag
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TagRepository @Inject constructor(
    private val tagDao: TagDao
) {
    fun getAllTags(): Flow<List<Tag>> {
        return tagDao.getAllTags().map { entities ->
            entities.map { Tag.fromEntity(it) }
        }
    }
    
    suspend fun getTagById(tagId: String): Tag? {
        return tagDao.getTagById(tagId)?.let { Tag.fromEntity(it) }
    }
    
    suspend fun createTag(
        name: String,
        icon: String = "tag",
        color: String? = null,
        sortOrder: Int? = null
    ): Tag {
        val order = sortOrder ?: (tagDao.getTagCount() + 1)
        val tag = TagEntity(
            id = UUID.randomUUID().toString(),
            name = name,
            icon = icon,
            color = color,
            isSystem = false,
            sortOrder = order
        )
        tagDao.insertTag(tag)
        return Tag.fromEntity(tag)
    }
    
    // Translation-Tag relationships
    suspend fun setTagsForTranslation(groupId: String, tagIds: List<String>) {
        // Remove all existing tags
        tagDao.deleteAllTagsForTranslation(groupId)
        
        // Add new tags
        tagIds.forEach { tagId ->
            tagDao.insertTranslationTagCrossRef(
                TranslationTagCrossRef(groupId, tagId)
            )
        }
    }
    
    suspend fun getTagsForTranslationSync(groupId: String): List<Tag> {
        return tagDao.getTagsForTranslationSync(groupId).map { Tag.fromEntity(it) }
    }
    
    suspend fun initializeDefaultTags() {
        val tagCount = tagDao.getTagCount()
        if (tagCount > 0) return
        
        val defaultTags = listOf(
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Greetings",
                icon = "hand.wave.fill",
                color = "FF9500", // Orange
                isSystem = true,
                sortOrder = 1
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Travel",
                icon = "airplane",
                color = "007AFF", // Blue
                isSystem = true,
                sortOrder = 2
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Dining",
                icon = "fork.knife",
                color = "FF2D55", // Red
                isSystem = true,
                sortOrder = 3
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Shopping",
                icon = "cart.fill",
                color = "AF52DE", // Purple
                isSystem = true,
                sortOrder = 4
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Directions",
                icon = "map.fill",
                color = "5AC8FA", // Light Blue
                isSystem = true,
                sortOrder = 5
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Emergency",
                icon = "exclamationmark.triangle.fill",
                color = "FF3B30", // Red
                isSystem = true,
                sortOrder = 6
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Numbers",
                icon = "number",
                color = "34C759", // Green
                isSystem = true,
                sortOrder = 7
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Time & Date",
                icon = "clock.fill",
                color = "FF9500", // Orange
                isSystem = true,
                sortOrder = 8
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "Weather",
                icon = "cloud.sun.fill",
                color = "FFCC00", // Yellow
                isSystem = true,
                sortOrder = 9
            ),
            TagEntity(
                id = UUID.randomUUID().toString(),
                name = "General",
                icon = "folder.fill",
                color = "8E8E93", // Gray
                isSystem = true,
                sortOrder = 10
            )
        )
        
        tagDao.insertTags(defaultTags)
    }
}
