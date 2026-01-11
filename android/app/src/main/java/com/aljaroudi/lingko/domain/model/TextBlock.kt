package com.aljaroudi.lingko.domain.model

import android.graphics.Rect
import java.util.UUID

data class TextBlock(
    val id: String = UUID.randomUUID().toString(),
    val text: String,
    val boundingBox: Rect,
    val confidence: Float? = null
)
