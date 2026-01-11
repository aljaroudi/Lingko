package com.aljaroudi.lingko.ui.image

import android.net.Uri
import com.aljaroudi.lingko.domain.model.TextBlock
import com.aljaroudi.lingko.domain.model.TranslationResult

data class ImageTranslationUiState(
    val imageUri: Uri? = null,
    val textBlocks: List<TextBlock> = emptyList(),
    val selectedTextBlock: TextBlock? = null,
    val showTranslationSheet: Boolean = false,
    val highlightedBlockId: String? = null,
    val isProcessing: Boolean = false,
    val error: String? = null,
    val translations: List<TranslationResult> = emptyList(),
    val isTranslating: Boolean = false
)
