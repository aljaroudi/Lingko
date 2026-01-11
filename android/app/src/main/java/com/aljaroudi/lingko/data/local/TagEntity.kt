package com.aljaroudi.lingko.data.local

import androidx.room.Entity
import androidx.room.PrimaryKey
import java.util.UUID

@Entity(tableName = "tags")
data class TagEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val name: String,
    val icon: String,
    val color: String?,
    val isSystem: Boolean = false,
    val sortOrder: Int
)
