package com.aljaroudi.lingko.data.local

import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [SavedTranslationEntity::class],
    version = 2,
    exportSchema = false
)
abstract class LingkoDatabase : RoomDatabase() {
    abstract fun translationHistoryDao(): TranslationHistoryDao
}
