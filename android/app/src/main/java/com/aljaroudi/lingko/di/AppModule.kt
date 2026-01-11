package com.aljaroudi.lingko.di

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.preferencesDataStore
import androidx.room.Room
import com.aljaroudi.lingko.data.local.LingkoDatabase
import com.aljaroudi.lingko.data.local.TagDao
import com.aljaroudi.lingko.data.local.TranslationHistoryDao
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore("settings")

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): LingkoDatabase {
        return Room.databaseBuilder(
            context,
            LingkoDatabase::class.java,
            "lingko_db"
        )
            .addMigrations(LingkoDatabase.MIGRATION_2_3)
            .fallbackToDestructiveMigration()
            .build()
    }

    @Provides
    fun provideTranslationHistoryDao(db: LingkoDatabase): TranslationHistoryDao {
        return db.translationHistoryDao()
    }
    
    @Provides
    fun provideTagDao(db: LingkoDatabase): TagDao {
        return db.tagDao()
    }

    @Provides
    @Singleton
    fun provideDataStore(@ApplicationContext context: Context): DataStore<Preferences> {
        return context.dataStore
    }
}
