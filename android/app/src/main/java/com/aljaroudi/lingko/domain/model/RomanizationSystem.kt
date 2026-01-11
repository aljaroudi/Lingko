package com.aljaroudi.lingko.domain.model

enum class RomanizationSystem(val displayName: String) {
    PINYIN_WITH_TONES("Pinyin (with tones)"),
    PINYIN_WITHOUT_TONES("Pinyin (no tones)"),
    ROMAJI_HEPBURN("Romaji (Hepburn)"),
    KOREAN_REVISED("Revised Romanization"),
    ARABIC_ALA_LC("ALA-LC"),
    CYRILLIC_BGN_PCGN("BGN/PCGN"),
    LATIN_ANY("Latin (any script)");

    fun getTransliteratorId(language: Language): String = when (this) {
        PINYIN_WITH_TONES -> "Han-Latin/Names"
        PINYIN_WITHOUT_TONES -> "Han-Latin/Names; Latin-ASCII"
        ROMAJI_HEPBURN -> "Katakana-Latin; Hiragana-Latin"
        KOREAN_REVISED -> "Hangul-Latin"
        ARABIC_ALA_LC -> "Arabic-Latin"
        CYRILLIC_BGN_PCGN -> "Cyrillic-Latin"
        LATIN_ANY -> "Any-Latin; Latin-ASCII"
    }
}
