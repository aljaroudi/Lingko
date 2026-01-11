package com.aljaroudi.lingko.ui.image.components

import android.net.Uri
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.IntSize
import coil.compose.SubcomposeAsyncImage
import coil.request.ImageRequest
import com.aljaroudi.lingko.domain.model.TextBlock

@Composable
fun ImageWithTextOverlay(
    imageUri: Uri,
    textBlocks: List<TextBlock>,
    highlightedBlockId: String?,
    onTextBlockTapped: (blockId: String) -> Unit,
    modifier: Modifier = Modifier
) {
    var displaySize by remember { mutableStateOf(IntSize.Zero) }
    var imageSize by remember { mutableStateOf<IntSize?>(null) }

    Box(
        modifier = modifier
            .fillMaxSize()
            .onSizeChanged { size ->
                displaySize = size
            }
    ) {
        SubcomposeAsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(imageUri)
                .crossfade(true)
                .build(),
            contentDescription = "Selected image with text",
            modifier = Modifier.fillMaxSize(),
            contentScale = ContentScale.Fit,
            loading = {
                Box(
                    modifier = Modifier.fillMaxSize(),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            },
            onSuccess = { state ->
                imageSize = IntSize(
                    state.painter.intrinsicSize.width.toInt(),
                    state.painter.intrinsicSize.height.toInt()
                )
            }
        )

        // Draw text block overlays
        imageSize?.let { imgSize ->
            val scaleX = displaySize.width.toFloat() / imgSize.width
            val scaleY = displaySize.height.toFloat() / imgSize.height
            val scale = minOf(scaleX, scaleY)

            val scaledWidth = imgSize.width * scale
            val scaledHeight = imgSize.height * scale
            val offsetX = (displaySize.width - scaledWidth) / 2
            val offsetY = (displaySize.height - scaledHeight) / 2

            Canvas(
                modifier = Modifier
                    .fillMaxSize()
                    .pointerInput(textBlocks) {
                        detectTapGestures { tapOffset ->
                            // Convert tap coordinates to image coordinates
                            val imageX = (tapOffset.x - offsetX) / scale
                            val imageY = (tapOffset.y - offsetY) / scale

                            // Find tapped text block
                            textBlocks.firstOrNull { block ->
                                block.boundingBox.contains(imageX.toInt(), imageY.toInt())
                            }?.let { block ->
                                onTextBlockTapped(block.id)
                            }
                        }
                    }
            ) {
                textBlocks.forEach { block ->
                    val rect = block.boundingBox
                    val left = offsetX + rect.left * scale
                    val top = offsetY + rect.top * scale
                    val right = offsetX + rect.right * scale
                    val bottom = offsetY + rect.bottom * scale

                    val isHighlighted = block.id == highlightedBlockId
                    val color = if (isHighlighted) {
                        Color(0xFF4CAF50).copy(alpha = 0.4f)
                    } else {
                        Color(0xFF2196F3).copy(alpha = 0.2f)
                    }
                    val strokeColor = if (isHighlighted) {
                        Color(0xFF4CAF50)
                    } else {
                        Color(0xFF2196F3)
                    }

                    // Draw filled rectangle
                    drawRect(
                        color = color,
                        topLeft = Offset(left, top),
                        size = Size(right - left, bottom - top)
                    )

                    // Draw border
                    drawRect(
                        color = strokeColor,
                        topLeft = Offset(left, top),
                        size = Size(right - left, bottom - top),
                        style = Stroke(width = 2f)
                    )
                }
            }
        }
    }
}
