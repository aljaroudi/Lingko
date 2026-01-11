package com.aljaroudi.lingko.ui.translation

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aljaroudi.lingko.data.repository.TranslationRepository
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.TranslationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class TranslationViewModel @Inject constructor(
    private val translationRepository: TranslationRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(TranslationUiState())
    val uiState = _uiState.asStateFlow()

    private var translationJob: Job? = null

    fun onTextChange(text: String) {
        _uiState.update { it.copy(inputText = text) }

        // Cancel previous translation job
        translationJob?.cancel()

        if (text.isBlank()) {
            _uiState.update {
                it.copy(
                    translations = emptyList(),
                    sourceLanguage = null,
                    error = null
                )
            }
            return
        }

        // Debounce translation by 500ms
        translationJob = viewModelScope.launch {
            delay(500)
            translateText(text)
        }
    }

    private suspend fun translateText(text: String) {
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
            return
        }

        _uiState.update { it.copy(sourceLanguage = sourceLanguage) }

        // Translate to all selected languages
        val results = mutableListOf<TranslationResult>()
        translationRepository.translateToMultiple(
            text = text,
            from = sourceLanguage.language,
            toLanguages = _uiState.value.selectedTargetLanguages
        ).collect { result ->
            results.add(result)
            _uiState.update { 
                it.copy(translations = results.sortedBy { r -> r.language.displayName }) 
            }
        }

        _uiState.update { it.copy(isTranslating = false) }
    }

    fun toggleLanguage(language: Language) {
        val currentLanguages = _uiState.value.selectedTargetLanguages
        val newLanguages = if (currentLanguages.contains(language)) {
            currentLanguages - language
        } else {
            currentLanguages + language
        }
        _uiState.update { it.copy(selectedTargetLanguages = newLanguages) }

        // Re-translate if there's input text
        if (_uiState.value.inputText.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch {
                delay(500)
                translateText(_uiState.value.inputText)
            }
        }
    }

    fun copyToClipboard(result: TranslationResult) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Translation", result.translation)
        clipboard.setPrimaryClip(clip)
    }

    fun speak(result: TranslationResult) {
        // Placeholder for Phase 4: Text-to-Speech
        // Will be implemented when AudioRepository is added
    }

    override fun onCleared() {
        super.onCleared()
        translationRepository.cleanup()
    }
}
