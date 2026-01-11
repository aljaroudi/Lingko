package com.aljaroudi.lingko.domain.model

import com.google.mlkit.nl.translate.TranslateLanguage

enum class Language(
    val code: String,
    val displayName: String,
    val nativeName: String,
    val script: Script,
    val mlKitCode: String
) {
    ENGLISH("en", "English", "English", Script.LATIN, TranslateLanguage.ENGLISH),
    SPANISH("es", "Spanish", "Español", Script.LATIN, TranslateLanguage.SPANISH),
    FRENCH("fr", "French", "Français", Script.LATIN, TranslateLanguage.FRENCH),
    GERMAN("de", "German", "Deutsch", Script.LATIN, TranslateLanguage.GERMAN),
    CHINESE_SIMPLIFIED("zh", "Chinese (Simplified)", "简体中文", Script.CHINESE, TranslateLanguage.CHINESE),
    JAPANESE("ja", "Japanese", "日本語", Script.JAPANESE, TranslateLanguage.JAPANESE),
    KOREAN("ko", "Korean", "한국어", Script.KOREAN, TranslateLanguage.KOREAN),
    ARABIC("ar", "Arabic", "العربية", Script.ARABIC, TranslateLanguage.ARABIC),
    RUSSIAN("ru", "Russian", "Русский", Script.CYRILLIC, TranslateLanguage.RUSSIAN),
    HINDI("hi", "Hindi", "हिन्दी", Script.DEVANAGARI, TranslateLanguage.HINDI),
    PORTUGUESE("pt", "Portuguese", "Português", Script.LATIN, TranslateLanguage.PORTUGUESE),
    ITALIAN("it", "Italian", "Italiano", Script.LATIN, TranslateLanguage.ITALIAN),
    DUTCH("nl", "Dutch", "Nederlands", Script.LATIN, TranslateLanguage.DUTCH),
    POLISH("pl", "Polish", "Polski", Script.LATIN, TranslateLanguage.POLISH),
    TURKISH("tr", "Turkish", "Türkçe", Script.LATIN, TranslateLanguage.TURKISH);

    companion object {
        fun fromCode(code: String): Language? = entries.find { it.code == code }

        fun fromMlKitCode(mlKitCode: String): Language? = entries.find { it.mlKitCode == mlKitCode }
    }
}
