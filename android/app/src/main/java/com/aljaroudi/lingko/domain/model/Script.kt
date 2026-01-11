package com.aljaroudi.lingko.domain.model

enum class Script {
    LATIN,
    CHINESE,
    JAPANESE,
    KOREAN,
    ARABIC,
    CYRILLIC,
    DEVANAGARI,
    THAI,
    HEBREW,
    GREEK;

    val needsRomanization: Boolean
        get() = this != LATIN

    val isRTL: Boolean
        get() = this == ARABIC || this == HEBREW
}
