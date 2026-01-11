package com.aljaroudi.lingko.ui.history

import com.aljaroudi.lingko.domain.model.Tag
import com.aljaroudi.lingko.domain.model.TranslationGroup

data class HistoryUiState(
    val translationGroups: List<TranslationGroup> = emptyList(),
    val searchQuery: String = "",
    val isLoading: Boolean = false,
    val availableTags: List<Tag> = emptyList()
)
