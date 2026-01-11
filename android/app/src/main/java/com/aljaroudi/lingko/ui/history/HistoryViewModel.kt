package com.aljaroudi.lingko.ui.history

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aljaroudi.lingko.data.repository.HistoryRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class HistoryViewModel @Inject constructor(
    private val historyRepository: HistoryRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(HistoryUiState())
    val uiState = _uiState.asStateFlow()

    private var searchJob: Job? = null

    init {
        loadHistory()
    }

    private fun loadHistory() {
        viewModelScope.launch {
            _uiState.update { it.copy(isLoading = true) }
            historyRepository.getRecentTranslations().collect { groups ->
                _uiState.update {
                    it.copy(
                        translationGroups = groups,
                        isLoading = false
                    )
                }
            }
        }
    }

    fun onSearchChange(query: String) {
        _uiState.update { it.copy(searchQuery = query) }

        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            delay(300) // Debounce
            if (query.isBlank()) {
                loadHistory()
            } else {
                historyRepository.searchTranslations(query).collect { groups ->
                    _uiState.update {
                        it.copy(
                            translationGroups = groups,
                            isLoading = false
                        )
                    }
                }
            }
        }
    }

    fun toggleFavorite(groupId: String) {
        viewModelScope.launch {
            historyRepository.toggleFavorite(groupId)
        }
    }

    fun delete(groupId: String) {
        viewModelScope.launch {
            historyRepository.delete(groupId)
        }
    }

    fun clearAll() {
        viewModelScope.launch {
            historyRepository.clearAll()
        }
    }
}
