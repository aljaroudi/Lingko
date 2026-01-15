package com.aljaroudi.lingko.ui.translation

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.aljaroudi.lingko.data.repository.AudioRepository
import com.aljaroudi.lingko.data.repository.HistoryRepository
import com.aljaroudi.lingko.data.repository.PreferencesRepository
import com.aljaroudi.lingko.data.repository.RomanizationRepository
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
    private val romanizationRepository: RomanizationRepository,
    private val audioRepository: AudioRepository,
    private val historyRepository: HistoryRepository,
    private val preferencesRepository: PreferencesRepository,
    @ApplicationContext private val context: Context
) : ViewModel() {

    private val _uiState = MutableStateFlow(TranslationUiState())
    val uiState = _uiState.asStateFlow()

    private var translationJob: Job? = null

    init {
        // Initialize Text-to-Speech
        viewModelScope.launch {
            try {
                audioRepository.initialize()
            } catch (e: Exception) {
                // TTS initialization failed, but app should continue to work
                // User just won't be able to use speech feature
            }
        }

        // Collect speaking state from AudioRepository
        viewModelScope.launch {
            audioRepository.isSpeaking.collect { isSpeaking ->
                _uiState.update { it.copy(isSpeaking = isSpeaking) }
            }
        }

        // Load preferences
        viewModelScope.launch {
            preferencesRepository.selectedLanguages.collect { languages ->
                _uiState.update { currentState ->
                    val newActivePriority = if (currentState.activePriorityLanguage == null ||
                                                !languages.contains(currentState.activePriorityLanguage)) {
                        // Set to first language alphabetically if current is not valid
                        languages.sortedBy { it.displayName }.firstOrNull()
                    } else {
                        currentState.activePriorityLanguage
                    }

                    currentState.copy(
                        selectedTargetLanguages = languages,
                        activePriorityLanguage = newActivePriority,
                        showRomanization = true
                    )
                }
            }
        }
    }

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

    fun setText(text: String) {
        // Set text and trigger translation immediately (no debounce for extracted text)
        _uiState.update { it.copy(inputText = text) }
        
        translationJob?.cancel()
        
        if (text.isNotBlank()) {
            translationJob = viewModelScope.launch {
                translateText(text)
            }
        }
    }

    private suspend fun translateText(text: String) {
        _uiState.update { it.copy(isTranslating = true, error = null) }

        // Detect language with priority for user-selected languages
        val detectedResult = translationRepository.detectLanguage(
            text = text,
            preferredLanguages = _uiState.value.selectedTargetLanguages
        )
        val sourceLanguage = detectedResult.getOrNull()

        // This should always succeed now with fallback, but keep null check for safety
        if (sourceLanguage == null) {
            _uiState.update {
                it.copy(
                    isTranslating = false,
                    error = "Could not detect language"
                )
            }
            return
        }

        // Get possible languages for user reference
        val possibleLanguages = translationRepository.detectPossibleLanguages(
            text = text,
            preferredLanguages = _uiState.value.selectedTargetLanguages,
            maxResults = 5
        )

        _uiState.update { currentState ->
            // If active priority language is same as new source, switch to another
            val newActivePriority = if (currentState.activePriorityLanguage == sourceLanguage.language) {
                currentState.selectedTargetLanguages
                    .filter { it != sourceLanguage.language }
                    .sortedBy { it.displayName }
                    .firstOrNull()
            } else {
                currentState.activePriorityLanguage
            }

            currentState.copy(
                sourceLanguage = sourceLanguage,
                possibleSourceLanguages = possibleLanguages,
                activePriorityLanguage = newActivePriority
            )
        }

        // Use effective source language (manual override or detected)
        val effectiveSource = _uiState.value.effectiveSourceLanguage ?: sourceLanguage.language

        // Filter out source language from target languages (don't translate to same language)
        val targetLanguages = _uiState.value.selectedTargetLanguages.filter { it != effectiveSource }.toSet()

        // If no target languages remain after filtering, show empty results
        if (targetLanguages.isEmpty()) {
            _uiState.update {
                it.copy(
                    translations = emptyList(),
                    isTranslating = false
                )
            }
            return
        }

        // Translate to all selected languages (excluding source)
        // Prioritize the active language if set
        val results = mutableListOf<TranslationResult>()
        translationRepository.translateToMultiple(
            text = text,
            from = effectiveSource,
            toLanguages = targetLanguages,
            priorityLanguage = _uiState.value.activePriorityLanguage
        ).collect { result ->
            // Add romanization if needed
            val withRomanization = if (result.language.script.needsRomanization) {
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

        // Save all translations to history with same groupId
        if (results.isNotEmpty()) {
            val groupId = java.util.UUID.randomUUID().toString()
            historyRepository.saveTranslations(results, text, groupId)
        }

        _uiState.update { it.copy(isTranslating = false) }
    }

    fun retryTranslation() {
        val currentText = _uiState.value.inputText
        if (currentText.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch {
                translateText(currentText)
            }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun toggleLanguage(language: Language) {
        viewModelScope.launch {
            val currentLanguages = _uiState.value.selectedTargetLanguages
            val newLanguages = if (currentLanguages.contains(language)) {
                currentLanguages - language
            } else {
                currentLanguages + language
            }

            // Save to preferences
            preferencesRepository.setSelectedLanguages(newLanguages)

            // Re-translate if there's input text
            if (_uiState.value.inputText.isNotBlank()) {
                translationJob?.cancel()
                translationJob = viewModelScope.launch {
                    delay(500)
                    translateText(_uiState.value.inputText)
                }
            }
        }
    }

    fun copyToClipboard(result: TranslationResult) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val clip = ClipData.newPlainText("Translation", result.translation)
        clipboard.setPrimaryClip(clip)
    }

    fun speak(result: TranslationResult) {
        audioRepository.speak(
            text = result.translation,
            language = result.language,
            rate = 1.0f
        )
    }

    fun setManualSourceLanguage(language: Language) {
        _uiState.update { currentState ->
            // If active priority language is same as new source, switch to another
            val newActivePriority = if (currentState.activePriorityLanguage == language) {
                currentState.selectedTargetLanguages
                    .filter { it != language }
                    .sortedBy { it.displayName }
                    .firstOrNull()
            } else {
                currentState.activePriorityLanguage
            }

            currentState.copy(
                manualSourceLanguage = language,
                activePriorityLanguage = newActivePriority
            )
        }

        // Re-translate with the new source language
        if (_uiState.value.inputText.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch {
                translateText(_uiState.value.inputText)
            }
        }
    }

    fun clearManualSourceLanguage() {
        _uiState.update { it.copy(manualSourceLanguage = null) }

        // Re-translate with auto-detected language
        if (_uiState.value.inputText.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch {
                translateText(_uiState.value.inputText)
            }
        }
    }

    fun setActivePriorityLanguage(language: Language) {
        _uiState.update { it.copy(activePriorityLanguage = language) }

        // If we already have a translation for this language, no need to re-translate
        // The UI will automatically show it via the activeTranslation computed property
    }

    override fun onCleared() {
        super.onCleared()
        translationRepository.cleanup()
        audioRepository.cleanup()
    }
}
