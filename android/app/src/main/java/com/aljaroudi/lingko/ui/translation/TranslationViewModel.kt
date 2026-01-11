package com.aljaroudi.lingko.ui.translation

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aljaroudi.lingko.data.repository.TranslationRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class TranslationViewModel @Inject constructor(
    private val translationRepository: TranslationRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(TranslationUiState())
    val uiState = _uiState.asStateFlow()

    fun onTextChange(text: String) {
        _uiState.update { it.copy(inputText = text) }

        if (text.isBlank()) {
            _uiState.update {
                it.copy(
                    translationResult = null,
                    sourceLanguage = null,
                    error = null
                )
            }
            return
        }

        translateText(text)
    }

    private fun translateText(text: String) {
        viewModelScope.launch {
            _uiState.update { it.copy(isTranslating = true, error = null) }

            // Detect language
            val detectedResult = translationRepository.detectLanguage(text)
            val sourceLanguage = detectedResult.getOrNull()

            if (sourceLanguage == null) {
                _uiState.update {
                    it.copy(
                        isTranslating = false,
                        error = "Could not detect language"
                    )
                }
                return@launch
            }

            _uiState.update { it.copy(sourceLanguage = sourceLanguage) }

            // Translate to target language
            val translationResult = translationRepository.translate(
                text = text,
                from = sourceLanguage.language,
                to = _uiState.value.selectedTargetLanguage
            )

            translationResult.onSuccess { translated ->
                _uiState.update {
                    it.copy(
                        translationResult = translated,
                        isTranslating = false
                    )
                }
            }.onFailure { exception ->
                _uiState.update {
                    it.copy(
                        isTranslating = false,
                        error = exception.message ?: "Translation failed"
                    )
                }
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        translationRepository.cleanup()
    }
}
