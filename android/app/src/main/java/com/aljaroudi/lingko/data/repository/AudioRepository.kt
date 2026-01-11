package com.aljaroudi.lingko.data.repository

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import com.aljaroudi.lingko.domain.model.Language
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.suspendCancellableCoroutine
import java.util.*
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

@Singleton
class AudioRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private var tts: TextToSpeech? = null
    private var isInitialized = false

    private val _isSpeaking = MutableStateFlow(false)
    val isSpeaking: StateFlow<Boolean> = _isSpeaking.asStateFlow()

    /**
     * Initialize the TextToSpeech engine.
     * Must be called before using speak() method.
     * Uses suspendCancellableCoroutine for clean async initialization.
     */
    suspend fun initialize() = suspendCancellableCoroutine { continuation ->
        tts = TextToSpeech(context) { status ->
            isInitialized = (status == TextToSpeech.SUCCESS)

            if (isInitialized) {
                // Set up utterance progress listener for state tracking
                tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                    override fun onStart(utteranceId: String) {
                        _isSpeaking.value = true
                    }

                    override fun onDone(utteranceId: String) {
                        _isSpeaking.value = false
                    }

                    override fun onError(utteranceId: String) {
                        _isSpeaking.value = false
                    }
                })

                continuation.resume(Unit)
            } else {
                continuation.resumeWithException(Exception("TTS initialization failed"))
            }
        }

        // Handle cancellation
        continuation.invokeOnCancellation {
            if (!isInitialized) {
                tts?.shutdown()
                tts = null
            }
        }
    }

    /**
     * Speak the given text in the specified language.
     * Automatically stops any previous speech before starting new one.
     *
     * @param text The text to speak
     * @param language The language for TTS voice selection
     * @param rate Speech rate (0.5f to 2.0f, default 1.0f)
     */
    fun speak(text: String, language: Language, rate: Float = 1.0f) {
        if (!isInitialized || tts == null) {
            return
        }

        tts?.apply {
            // Stop any previous speech
            stop()

            // Set speech parameters
            setSpeechRate(rate.coerceIn(0.5f, 2.0f))
            setPitch(1.0f)

            // Set language using Locale from language code
            val locale = Locale.forLanguageTag(language.code)
            setLanguage(locale)

            // Speak the text with utterance ID for progress tracking
            speak(text, TextToSpeech.QUEUE_FLUSH, null, "utterance_id")
        }
    }

    /**
     * Stop the current speech immediately.
     * Also updates the isSpeaking state to false.
     */
    fun stop() {
        tts?.stop()
        _isSpeaking.value = false
    }

    /**
     * Cleanup TTS resources.
     * Should be called when the repository is no longer needed.
     */
    fun cleanup() {
        tts?.shutdown()
        tts = null
        isInitialized = false
        _isSpeaking.value = false
    }
}
