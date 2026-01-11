package com.aljaroudi.lingko.domain.model

import com.aljaroudi.lingko.data.local.TagEntity

data class Tag(
    val id: String,
    val name: String,
    val icon: String,
    val color: String?,
    val isSystem: Boolean,
    val sortOrder: Int
) {
    fun toEntity() = TagEntity(
        id = id,
        name = name,
        icon = icon,
        color = color,
        isSystem = isSystem,
        sortOrder = sortOrder
    )
    
    companion object {
        fun fromEntity(entity: TagEntity) = Tag(
            id = entity.id,
            name = entity.name,
            icon = entity.icon,
            color = entity.color,
            isSystem = entity.isSystem,
            sortOrder = entity.sortOrder
        )
    }
}
