package com.aljaroudi.lingko.data.repository

import android.content.Context
import android.graphics.Rect
import android.net.Uri
import com.aljaroudi.lingko.domain.model.TextBlock
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class TextRecognitionRepository @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)

    suspend fun recognizeText(uri: Uri): Result<List<TextBlock>> = withContext(Dispatchers.IO) {
        try {
            val inputImage = InputImage.fromFilePath(context, uri)
            val visionText = recognizer.process(inputImage).await()
            
            val textBlocks = visionText.textBlocks.mapNotNull { block ->
                block.boundingBox?.let { box ->
                    TextBlock(
                        text = block.text,
                        boundingBox = Rect(box.left, box.top, box.right, box.bottom),
                        confidence = null  // ML Kit TextBlocks don't have confidence at block level
                    )
                }
            }
            
            if (textBlocks.isEmpty()) {
                Result.failure(Exception("No text found in image"))
            } else {
                Result.success(textBlocks)
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
