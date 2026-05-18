package com.aljaroudi.lingko.ui.history.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.aljaroudi.lingko.R
import com.aljaroudi.lingko.domain.model.GroupedTranslationItem
import com.aljaroudi.lingko.domain.model.TranslationGroup
import com.aljaroudi.lingko.ui.tags.TagChip
import com.aljaroudi.lingko.ui.translation.components.TranslationResultCard
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryItem(
    group: TranslationGroup,
    speakingItemId: String?,
    onSpeak: (GroupedTranslationItem) -> Unit,
    onCopy: (String) -> Unit,
    onFavoriteToggle: () -> Unit,
    onDelete: () -> Unit,
    onEditTags: () -> Unit,
    modifier: Modifier = Modifier
) {
    val dateFormatter = SimpleDateFormat("MMM dd, yyyy HH:mm", Locale.getDefault())
    val sourceLangName = group.sourceLanguage?.displayName ?: stringResource(R.string.label_auto_detect)

    val dismissState = rememberSwipeToDismissBoxState(
        confirmValueChange = { dismissValue ->
            if (dismissValue == SwipeToDismissBoxValue.EndToStart) {
                onDelete()
                true
            } else false
        }
    )

    SwipeToDismissBox(
        state = dismissState,
        backgroundContent = {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
                contentAlignment = Alignment.CenterEnd
            ) {
                Icon(
                    imageVector = Icons.Default.Delete,
                    contentDescription = stringResource(R.string.cd_delete),
                    tint = MaterialTheme.colorScheme.error
                )
            }
        },
        enableDismissFromStartToEnd = false,
        modifier = modifier
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp)
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                group.translations.forEachIndexed { index, item ->
                    val itemId = "${group.groupId}:${item.targetLanguage.code}"
                    TranslationResultCard(
                        sourceLanguageName = sourceLangName,
                        sourceText = group.sourceText,
                        targetLanguageName = item.targetLanguage.displayName,
                        translation = item.translatedText,
                        romanization = item.romanization,
                        isRTL = item.targetLanguage.script.isRTL,
                        isSpeaking = speakingItemId == itemId,
                        isFavorite = group.isFavorite,
                        onSpeak = { onSpeak(item) },
                        onCopy = { onCopy(item.translatedText) },
                        onFavoriteToggle = onFavoriteToggle
                    )
                    if (index < group.translations.lastIndex) {
                        HorizontalDivider(modifier = Modifier.padding(horizontal = 16.dp))
                    }
                }

                // Tags + timestamp footer
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .padding(bottom = 12.dp)
                ) {
                    if (group.tags.isNotEmpty()) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(bottom = 6.dp),
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            group.tags.take(3).forEach { tag -> TagChip(tag = tag) }
                            if (group.tags.size > 3) {
                                Text(
                                    text = "+${group.tags.size - 3}",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Spacer(modifier = Modifier.weight(1f))
                            TextButton(
                                onClick = onEditTags,
                                contentPadding = PaddingValues(horizontal = 8.dp, vertical = 0.dp)
                            ) {
                                Text(
                                    text = "Edit tags",
                                    style = MaterialTheme.typography.labelSmall
                                )
                            }
                        }
                    } else {
                        TextButton(
                            onClick = onEditTags,
                            contentPadding = PaddingValues(horizontal = 0.dp, vertical = 0.dp)
                        ) {
                            Text(
                                text = "Add tags",
                                style = MaterialTheme.typography.labelSmall
                            )
                        }
                    }
                    Text(
                        text = dateFormatter.format(Date(group.timestamp)),
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
                    )
                }
            }
        }
    }
}
