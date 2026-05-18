package com.aljaroudi.lingko.ui.translation.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.PauseCircle
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import com.aljaroudi.lingko.R
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.domain.model.TranslationResult
import com.aljaroudi.lingko.ui.theme.LingkoTheme

@Composable
fun TranslationResultCard(
    sourceLanguageName: String,
    sourceText: String,
    targetLanguageName: String,
    translation: String,
    romanization: String?,
    isRTL: Boolean,
    isSpeaking: Boolean,
    isFavorite: Boolean,
    onSpeak: () -> Unit,
    onCopy: () -> Unit,
    onFavoriteToggle: () -> Unit,
    onTapSource: (() -> Unit)? = null,
    modifier: Modifier = Modifier
) {
    val accent = MaterialTheme.colorScheme.tertiary

    Column(modifier = modifier.fillMaxWidth()) {
        // Source section
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(if (onTapSource != null) Modifier.clickable { onTapSource() } else Modifier)
                .padding(16.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = sourceLanguageName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = sourceText,
                    style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold)
                )
            }
            Icon(
                imageVector = Icons.Default.PlayCircle,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.3f),
                modifier = Modifier
                    .padding(start = 12.dp, top = 4.dp)
                    .size(28.dp)
            )
        }

        HorizontalDivider()

        // Target section
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = targetLanguageName,
                        style = MaterialTheme.typography.bodySmall,
                        color = accent
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    CompositionLocalProvider(
                        LocalLayoutDirection provides if (isRTL) LayoutDirection.Rtl else LayoutDirection.Ltr
                    ) {
                        Text(
                            text = translation,
                            style = MaterialTheme.typography.titleLarge,
                            color = accent,
                            modifier = Modifier.fillMaxWidth()
                        )
                    }
                    if (romanization != null) {
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = romanization,
                            style = MaterialTheme.typography.bodySmall.copy(fontStyle = FontStyle.Italic),
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                IconButton(
                    onClick = onSpeak,
                    modifier = Modifier.size(40.dp)
                ) {
                    Icon(
                        imageVector = if (isSpeaking) Icons.Default.PauseCircle else Icons.Default.PlayCircle,
                        contentDescription = stringResource(
                            if (isSpeaking) R.string.cd_stop_speaking else R.string.cd_speak_translation
                        ),
                        tint = accent,
                        modifier = Modifier.size(28.dp)
                    )
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Action row
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                IconButton(onClick = onFavoriteToggle, modifier = Modifier.size(36.dp)) {
                    Icon(
                        imageVector = if (isFavorite) Icons.Default.Star else Icons.Default.StarBorder,
                        contentDescription = stringResource(
                            if (isFavorite) R.string.cd_remove_from_favorites else R.string.cd_add_to_favorites
                        ),
                        tint = if (isFavorite) MaterialTheme.colorScheme.error else accent,
                        modifier = Modifier.size(22.dp)
                    )
                }
                IconButton(onClick = onCopy, modifier = Modifier.size(36.dp)) {
                    Icon(
                        imageVector = Icons.Default.ContentCopy,
                        contentDescription = stringResource(R.string.cd_copy_translation),
                        tint = accent,
                        modifier = Modifier.size(22.dp)
                    )
                }
            }
        }
    }
}

@Preview(showBackground = true)
@Composable
private fun TranslationResultCardPreview() {
    LingkoTheme {
        TranslationResultCard(
            sourceLanguageName = "English (US)",
            sourceText = "Hello, world!",
            targetLanguageName = "Russian",
            translation = "Привет, мир!",
            romanization = null,
            isRTL = false,
            isSpeaking = false,
            isFavorite = false,
            onSpeak = {},
            onCopy = {},
            onFavoriteToggle = {}
        )
    }
}
