package com.aljaroudi.lingko.ui.image.components

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.aljaroudi.lingko.domain.model.TextBlock
import com.aljaroudi.lingko.domain.model.TranslationResult
import com.aljaroudi.lingko.ui.translation.components.TranslationResultCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TranslationBottomSheet(
    selectedTextBlock: TextBlock,
    translations: List<TranslationResult>,
    isTranslating: Boolean,
    showRomanization: Boolean,
    onDismiss: () -> Unit,
    onSpeak: (TranslationResult) -> Unit,
    onCopy: (TranslationResult) -> Unit,
    onTranslateAll: () -> Unit,
    modifier: Modifier = Modifier
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        modifier = modifier
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 16.dp)
        ) {
            // Header with original text
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp)
            ) {
                Text(
                    text = "Selected Text",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = selectedTextBlock.text,
                    style = MaterialTheme.typography.bodyLarge,
                    modifier = Modifier.padding(bottom = 8.dp)
                )
                HorizontalDivider()
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Translations section
            if (isTranslating) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator()
                }
            } else if (translations.isNotEmpty()) {
                LazyColumn(
                    modifier = Modifier.fillMaxWidth(),
                    contentPadding = PaddingValues(vertical = 8.dp)
                ) {
                    items(
                        items = translations,
                        key = { it.id }
                    ) { result ->
                        TranslationResultCard(
                            result = result,
                            showRomanization = showRomanization,
                            onSpeak = { onSpeak(result) },
                            onCopy = { onCopy(result) }
                        )
                    }
                }
            } else {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(32.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "No translations yet",
                        style = MaterialTheme.typography.bodyLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            // Action button
            Button(
                onClick = onTranslateAll,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            ) {
                Text("Translate All Text from Image")
            }
        }
    }
}
