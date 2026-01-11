package com.aljaroudi.lingko.data.repository

import android.content.Context
import com.aljaroudi.lingko.domain.model.DetectedLanguage
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.TranslationResult
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.channels.awaitClose
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.callbackFlow
import kotlinx.coroutines.flow.channelFlow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TranslationRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val languageIdentifier = LanguageIdentification.getClient()
    private val translators = mutableMapOf<String, Translator>()

    suspend fun detectLanguage(text: String): Result<DetectedLanguage> = withContext(Dispatchers.IO) {
        try {
            val languageCode = languageIdentifier.identifyLanguage(text).await()

            if (languageCode == "und") {
                return@withContext Result.failure(Exception("Language not detected"))
            }

            val language = Language.fromMlKitCode(languageCode)
                ?: return@withContext Result.failure(Exception("Unsupported language: $languageCode"))

            Result.success(DetectedLanguage(language, confidence = 1.0f))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun translate(
        text: String,
        from: Language,
        to: Language
    ): Result<String> = withContext(Dispatchers.IO) {
        try {
            val translator = getOrCreateTranslator(from, to)

            // Ensure model is downloaded
            translator.downloadModelIfNeeded().await()

            val translated = translator.translate(text).await()
            Result.success(translated)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun getOrCreateTranslator(from: Language, to: Language): Translator {
        val key = "${from.code}_${to.code}"
        return translators.getOrPut(key) {
            val options = TranslatorOptions.Builder()
                .setSourceLanguage(from.mlKitCode)
                .setTargetLanguage(to.mlKitCode)
                .build()
            Translation.getClient(options)
        }
    }

    suspend fun translateToMultiple(
        text: String,
        from: Language,
        toLanguages: Set<Language>
    ): Flow<TranslationResult> = channelFlow {
        toLanguages.map { targetLang ->
            async {
                val result = translate(text, from, targetLang)
                result.onSuccess { translated ->
                    send(
                        TranslationResult(
                            language = targetLang,
                            sourceLanguage = from,
                            translation = translated,
                            detectionConfidence = 1.0f
                        )
                    )
                }
            }
        }.awaitAll()
    }.flowOn(Dispatchers.IO)

    suspend fun isModelDownloaded(from: Language, to: Language): Boolean = withContext(Dispatchers.IO) {
        try {
            val modelManager = RemoteModelManager.getInstance()
            val model = TranslateRemoteModel.Builder(to.mlKitCode).build()
            modelManager.isModelDownloaded(model).await()
        } catch (e: Exception) {
            false
        }
    }

    suspend fun downloadModel(
        from: Language,
        to: Language
    ): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            val translator = getOrCreateTranslator(from, to)
            translator.downloadModelIfNeeded().await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    fun cleanup() {
        translators.values.forEach { it.close() }
        translators.clear()
        languageIdentifier.close()
    }
}

data class DownloadProgress(val percent: Int)
