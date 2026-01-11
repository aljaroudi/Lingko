package com.aljaroudi.lingko.util

import android.os.Build
import com.aljaroudi.lingko.domain.model.Language
import java.util.Locale

object LocaleHelper {
    /**
     * Get smart default languages based on device locale.
     * Logic:
     * 1. Get device locale
     * 2. Map to supported Language enum
     * 3. If device language is English → add Spanish
     * 4. Else if device language is Spanish → add English
     * 5. Otherwise → add English
     * 6. Ensure at least 2 languages selected (add Spanish if only 1)
     */
    fun getSmartDefaultLanguages(): Set<Language> {
        val deviceLocale = getDeviceLocale()
        val deviceLanguageCode = deviceLocale.language.lowercase()
        
        // Try to find matching Language enum
        val deviceLanguage = Language.entries.find { 
            it.code.lowercase() == deviceLanguageCode 
        }
        
        val languages = mutableSetOf<Language>()
        
        when {
            // If device is English, add Spanish
            deviceLanguage == Language.ENGLISH -> {
                languages.add(Language.ENGLISH)
                languages.add(Language.SPANISH)
            }
            // If device is Spanish, add English
            deviceLanguage == Language.SPANISH -> {
                languages.add(Language.SPANISH)
                languages.add(Language.ENGLISH)
            }
            // If device language is supported, add it plus English
            deviceLanguage != null -> {
                languages.add(deviceLanguage)
                languages.add(Language.ENGLISH)
            }
            // Fallback: English + Spanish
            else -> {
                languages.add(Language.ENGLISH)
                languages.add(Language.SPANISH)
            }
        }
        
        // Ensure at least 2 languages (add Spanish if only 1)
        if (languages.size < 2) {
            languages.add(Language.SPANISH)
        }
        
        return languages
    }
    
    /**
     * Get the device's primary locale.
     * Handles both legacy and modern Android APIs.
     */
    private fun getDeviceLocale(): Locale {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            // Android 7.0+ supports multiple locales
            val localeList = android.os.LocaleList.getDefault()
            if (localeList.isEmpty) {
                Locale.getDefault()
            } else {
                localeList[0]
            }
        } else {
            Locale.getDefault()
        }
    }
    
    /**
     * Get device language as a Language enum, or null if not supported.
     */
    fun getDeviceLanguage(): Language? {
        val deviceLocale = getDeviceLocale()
        val deviceLanguageCode = deviceLocale.language.lowercase()
        return Language.entries.find { it.code.lowercase() == deviceLanguageCode }
    }
}
