package com.aljaroudi.lingko.data.repository

import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.RomanizationSystem
import com.aljaroudi.lingko.domain.model.Script
import com.ibm.icu.text.Transliterator
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class RomanizationRepository @Inject constructor() {

    /**
     * Romanize text using the appropriate transliteration system
     * Returns null if the text doesn't need romanization or if an error occurs
     */
    fun romanize(
        text: String,
        language: Language,
        system: RomanizationSystem = language.defaultRomanizationSystem
    ): String? {
        // Skip romanization for Latin scripts
        if (!language.script.needsRomanization) return null

        return try {
            val transliteratorId = system.getTransliteratorId(language)
            val transliterator = Transliterator.getInstance(transliteratorId)
            transliterator.transliterate(text)
        } catch (e: Exception) {
            // Return null if transliteration fails
            null
        }
    }

    /**
     * Get available romanization systems for a given language
     */
    fun availableSystems(language: Language): List<RomanizationSystem> {
        return when (language.script) {
            Script.CHINESE -> listOf(
                RomanizationSystem.PINYIN_WITH_TONES,
                RomanizationSystem.PINYIN_WITHOUT_TONES
            )
            Script.JAPANESE -> listOf(RomanizationSystem.ROMAJI_HEPBURN)
            Script.KOREAN -> listOf(RomanizationSystem.KOREAN_REVISED)
            Script.ARABIC -> listOf(RomanizationSystem.ARABIC_ALA_LC)
            Script.CYRILLIC -> listOf(RomanizationSystem.CYRILLIC_BGN_PCGN)
            else -> listOf(RomanizationSystem.LATIN_ANY)
        }
    }
}
