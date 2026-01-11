package com.aljaroudi.lingko.ui.image

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aljaroudi.lingko.data.repository.AudioRepository
import com.aljaroudi.lingko.data.repository.PreferencesRepository
import com.aljaroudi.lingko.data.repository.RomanizationRepository
import com.aljaroudi.lingko.data.repository.TextRecognitionRepository
import com.aljaroudi.lingko.data.repository.TranslationRepository
import com.aljaroudi.lingko.domain.model.TranslationResult
import dagger.hilt.android.lifecycle.HiltViewModel
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ImageTranslationViewModel @Inject constructor(
    private val textRecognitionRepository: TextRecognitionRepository,
    private val translationRepository: TranslationRepository,
    private val romanizationRepository: RomanizationRepository,
    private val audioRepository: AudioRepository,
    private val preferencesRepository: PreferencesRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(ImageTranslationUiState())
    val uiState = _uiState.asStateFlow()

    fun processImage(uri: Uri) {
        viewModelScope.launch {
            _uiState.update { 
                it.copy(
                    isProcessing = true, 
                    error = null,
                    imageUri = uri,
                    textBlocks = emptyList(),
                    selectedTextBlock = null,
                    showTranslationSheet = false
                ) 
            }

            val result = textRecognitionRepository.recognizeText(uri)
            
            result.onSuccess { textBlocks ->
                _uiState.update { 
                    it.copy(
                        textBlocks = textBlocks,
                        isProcessing = false
                    )
                }
            }.onFailure { exception ->
                val errorMessage = when {
                    exception.message?.contains("No text found") == true -> "No text found in image"
                    else -> "Failed to extract text: ${exception.message ?: "Unknown error"}"
                }
                _uiState.update { 
                    it.copy(
                        error = errorMessage,
                        isProcessing = false
                    )
                }
            }
        }
    }

    fun selectTextBlock(blockId: String) {
        val textBlock = _uiState.value.textBlocks.firstOrNull { it.id == blockId }
        if (textBlock != null) {
            _uiState.update {
                it.copy(
                    selectedTextBlock = textBlock,
                    highlightedBlockId = blockId,
                    showTranslationSheet = true
                )
            }
            // Start translation immediately
            translateSelectedText()
        }
    }

    fun dismissTranslationSheet() {
        _uiState.update {
            it.copy(
                showTranslationSheet = false,
                highlightedBlockId = null,
                translations = emptyList()
            )
        }
    }

    private fun translateSelectedText() {
        viewModelScope.launch {
            val selectedText = _uiState.value.selectedTextBlock?.text ?: return@launch
            
            _uiState.update { it.copy(isTranslating = true) }

            // Detect language
            val detectedResult = translationRepository.detectLanguage(selectedText)
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

            // Get target languages from preferences
            val targetLanguages = preferencesRepository.selectedLanguages.first()
            val showRomanization = preferencesRepository.showRomanization.first()

            // Translate to all selected languages
            val results = mutableListOf<TranslationResult>()
            translationRepository.translateToMultiple(
                text = selectedText,
                from = sourceLanguage.language,
                toLanguages = targetLanguages
            ).collect { result ->
                // Add romanization if needed
                val withRomanization = if (result.language.script.needsRomanization && showRomanization) {
                    result.copy(
                        romanization = romanizationRepository.romanize(
                            result.translation,
                            result.language
                        )
                    )
                } else result

                results.add(withRomanization)
                _uiState.update {
                    it.copy(translations = results.sortedBy { r -> r.language.displayName })
                }
            }

            _uiState.update { it.copy(isTranslating = false) }
        }
    }

    fun getAllTextForTranslation(): String {
        return _uiState.value.textBlocks.joinToString("\n") { it.text }
    }

    fun speak(result: TranslationResult) {
        audioRepository.speak(
            text = result.translation,
            language = result.language,
            rate = 1.0f
        )
    }

    fun copyToClipboard(result: TranslationResult) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Translation", result.translation)
        clipboard.setPrimaryClip(clip)
    }

    fun clearState() {
        _uiState.value = ImageTranslationUiState()
    }

    override fun onCleared() {
        super.onCleared()
        // Don't call cleanup() - TextRecognitionRepository is a singleton and should persist
        // across ViewModel instances. Closing the recognizer would break subsequent uses.
    }
}
