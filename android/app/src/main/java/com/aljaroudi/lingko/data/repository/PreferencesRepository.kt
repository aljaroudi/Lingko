package com.aljaroudi.lingko.data.repository

import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.stringSetPreferencesKey
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.util.LocaleHelper
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PreferencesRepository @Inject constructor(
    private val dataStore: DataStore<Preferences>
) {
    private object Keys {
        val SELECTED_LANGUAGES = stringSetPreferencesKey("selected_languages")
        val SHOW_ROMANIZATION = booleanPreferencesKey("show_romanization")
        val SPEECH_RATE = floatPreferencesKey("speech_rate")
    }

    val selectedLanguages: Flow<Set<Language>> = dataStore.data.map { prefs ->
        prefs[Keys.SELECTED_LANGUAGES]?.mapNotNull { Language.fromCode(it) }?.toSet()
            ?: getDefaultLanguages()
    }

    val showRomanization: Flow<Boolean> = dataStore.data.map { prefs ->
        prefs[Keys.SHOW_ROMANIZATION] ?: true
    }

    val speechRate: Flow<Float> = dataStore.data.map { prefs ->
        prefs[Keys.SPEECH_RATE] ?: 1.0f
    }

    suspend fun setSelectedLanguages(languages: Set<Language>) {
        dataStore.edit { prefs ->
            prefs[Keys.SELECTED_LANGUAGES] = languages.map { it.code }.toSet()
        }
    }

    suspend fun toggleRomanization() {
        dataStore.edit { prefs ->
            prefs[Keys.SHOW_ROMANIZATION] = !(prefs[Keys.SHOW_ROMANIZATION] ?: true)
        }
    }

    suspend fun setSpeechRate(rate: Float) {
        dataStore.edit { prefs ->
            prefs[Keys.SPEECH_RATE] = rate.coerceIn(0.5f, 2.0f)
        }
    }

    private fun getDefaultLanguages(): Set<Language> {
        // Use smart default based on device locale
        return LocaleHelper.getSmartDefaultLanguages()
    }
}
