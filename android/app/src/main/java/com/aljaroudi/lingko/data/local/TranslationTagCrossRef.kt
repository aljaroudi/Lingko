package com.aljaroudi.lingko.data.local

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index

@Entity(
    tableName = "translation_tags",
    primaryKeys = ["translationGroupId", "tagId"],
    foreignKeys = [
        ForeignKey(
            entity = TagEntity::class,
            parentColumns = ["id"],
            childColumns = ["tagId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("translationGroupId"), Index("tagId")]
)
data class TranslationTagCrossRef(
    val translationGroupId: String,
    val tagId: String
)
