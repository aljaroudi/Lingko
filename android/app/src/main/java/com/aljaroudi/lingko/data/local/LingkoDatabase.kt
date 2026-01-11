package com.aljaroudi.lingko.data.local

import androidx.room.Database
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

@Database(
    entities = [
        SavedTranslationEntity::class,
        TagEntity::class,
        TranslationTagCrossRef::class
    ],
    version = 3,
    exportSchema = false
)
abstract class LingkoDatabase : RoomDatabase() {
    abstract fun translationHistoryDao(): TranslationHistoryDao
    abstract fun tagDao(): TagDao
    
    companion object {
        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // Create tags table
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS tags (
                        id TEXT PRIMARY KEY NOT NULL,
                        name TEXT NOT NULL,
                        icon TEXT NOT NULL,
                        color TEXT,
                        isSystem INTEGER NOT NULL DEFAULT 0,
                        sortOrder INTEGER NOT NULL
                    )
                """)
                
                // Create translation_tags junction table
                db.execSQL("""
                    CREATE TABLE IF NOT EXISTS translation_tags (
                        translationGroupId TEXT NOT NULL,
                        tagId TEXT NOT NULL,
                        PRIMARY KEY (translationGroupId, tagId),
                        FOREIGN KEY (tagId) REFERENCES tags(id) ON DELETE CASCADE
                    )
                """)
                
                // Create indices for better query performance
                db.execSQL("CREATE INDEX IF NOT EXISTS index_translation_tags_translationGroupId ON translation_tags(translationGroupId)")
                db.execSQL("CREATE INDEX IF NOT EXISTS index_translation_tags_tagId ON translation_tags(tagId)")
            }
        }
    }
}
