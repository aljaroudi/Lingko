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
        viewModelScope.launch {
            try {
                audioRepository.initialize()
            } catch (e: Exception) {
                // TTS init failed — app continues without speech
            }
        }

        viewModelScope.launch {
            audioRepository.isSpeaking.collect { isSpeaking ->
                _uiState.update { it.copy(isSpeaking = isSpeaking) }
            }
        }

        viewModelScope.launch {
            preferencesRepository.selectedLanguages.collect { languages ->
                _uiState.update { currentState ->
                    val newTarget = when {
                        currentState.selectedTargetLanguage != null &&
                            languages.contains(currentState.selectedTargetLanguage) ->
                            currentState.selectedTargetLanguage
                        else -> languages.sortedBy { it.displayName }.firstOrNull()
                    }
                    currentState.copy(
                        selectedTargetLanguages = languages,
                        selectedTargetLanguage = newTarget,
                        showRomanization = true
                    )
                }
            }
        }
    }

    fun onTextChange(text: String) {
        _uiState.update { it.copy(inputText = text) }
        translationJob?.cancel()
        if (text.isBlank()) {
            _uiState.update { it.copy(translation = null, sourceLanguage = null, error = null) }
            return
        }
        translationJob = viewModelScope.launch {
            delay(500)
            translateText(text)
        }
    }

    fun setText(text: String) {
        _uiState.update { it.copy(inputText = text) }
        translationJob?.cancel()
        if (text.isNotBlank()) {
            translationJob = viewModelScope.launch { translateText(text) }
        }
    }

    private suspend fun translateText(text: String) {
        _uiState.update { it.copy(isTranslating = true, error = null) }

        val detectedResult = translationRepository.detectLanguage(
            text = text,
            preferredLanguages = _uiState.value.selectedTargetLanguages
        )
        val sourceLanguage = detectedResult.getOrNull()
        if (sourceLanguage == null) {
            _uiState.update { it.copy(isTranslating = false, error = "Could not detect language") }
            return
        }

        val possibleLanguages = translationRepository.detectPossibleLanguages(
            text = text,
            preferredLanguages = _uiState.value.selectedTargetLanguages,
            maxResults = 5
        )

        _uiState.update { currentState ->
            val newTarget = if (currentState.selectedTargetLanguage == sourceLanguage.language) {
                currentState.selectedTargetLanguages
                    .filter { it != sourceLanguage.language }
                    .sortedBy { it.displayName }
                    .firstOrNull()
            } else {
                currentState.selectedTargetLanguage
            }
            currentState.copy(
                sourceLanguage = sourceLanguage,
                possibleSourceLanguages = possibleLanguages,
                selectedTargetLanguage = newTarget
            )
        }

        val effectiveSource = _uiState.value.effectiveSourceLanguage ?: sourceLanguage.language
        val targetLanguage = _uiState.value.selectedTargetLanguage

        if (targetLanguage == null || targetLanguage == effectiveSource) {
            _uiState.update { it.copy(translation = null, isTranslating = false) }
            return
        }

        translationRepository.translateToMultiple(
            text = text,
            from = effectiveSource,
            toLanguages = setOf(targetLanguage),
            priorityLanguage = targetLanguage
        ).collect { result ->
            val withRomanization = if (result.language.script.needsRomanization) {
                result.copy(
                    romanization = romanizationRepository.romanize(result.translation, result.language)
                )
            } else result

            _uiState.update { it.copy(translation = withRomanization) }
        }

        val finalResult = _uiState.value.translation
        if (finalResult != null) {
            val groupId = java.util.UUID.randomUUID().toString()
            historyRepository.saveTranslations(listOf(finalResult), text, groupId)
        }

        _uiState.update { it.copy(isTranslating = false) }
    }

    fun retryTranslation() {
        val text = _uiState.value.inputText
        if (text.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch { translateText(text) }
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    fun toggleLanguage(language: Language) {
        viewModelScope.launch {
            val newLanguages = _uiState.value.selectedTargetLanguages.let {
                if (it.contains(language)) it - language else it + language
            }
            preferencesRepository.setSelectedLanguages(newLanguages)
            if (_uiState.value.inputText.isNotBlank()) {
                translationJob?.cancel()
                translationJob = viewModelScope.launch { delay(500); translateText(_uiState.value.inputText) }
            }
        }
    }

    fun copyToClipboard(text: String) {
        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        clipboard.setPrimaryClip(ClipData.newPlainText("Translation", text))
    }

    fun speak(result: TranslationResult) {
        audioRepository.speak(text = result.translation, language = result.language, rate = 1.0f)
    }

    fun setManualSourceLanguage(language: Language) {
        _uiState.update { currentState ->
            val newTarget = if (currentState.selectedTargetLanguage == language) {
                currentState.selectedTargetLanguages
                    .filter { it != language }
                    .sortedBy { it.displayName }
                    .firstOrNull()
            } else currentState.selectedTargetLanguage
            currentState.copy(manualSourceLanguage = language, selectedTargetLanguage = newTarget)
        }
        if (_uiState.value.inputText.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch { translateText(_uiState.value.inputText) }
        }
    }

    fun clearManualSourceLanguage() {
        _uiState.update { it.copy(manualSourceLanguage = null) }
        if (_uiState.value.inputText.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch { translateText(_uiState.value.inputText) }
        }
    }

    fun onTargetLanguageSelected(language: Language) {
        _uiState.update { it.copy(selectedTargetLanguage = language, translation = null) }
        if (_uiState.value.inputText.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch { translateText(_uiState.value.inputText) }
        }
    }

    fun swap() {
        val state = _uiState.value
        val newSource = state.selectedTargetLanguage
        val newTarget = state.effectiveSourceLanguage
        val newInput = state.translation?.translation ?: state.inputText
        _uiState.update {
            it.copy(
                manualSourceLanguage = newSource,
                selectedTargetLanguage = newTarget,
                inputText = newInput,
                translation = null,
                sourceLanguage = null
            )
        }
        if (newInput.isNotBlank()) {
            translationJob?.cancel()
            translationJob = viewModelScope.launch { translateText(newInput) }
        }
    }

    override fun onCleared() {
        super.onCleared()
        translationRepository.cleanup()
        audioRepository.cleanup()
    }
}
