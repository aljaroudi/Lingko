package com.aljaroudi.lingko.ui.translation

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.Crossfade
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.navigation.compose.rememberNavController
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aljaroudi.lingko.R
import com.aljaroudi.lingko.ui.components.EmptyState
import com.aljaroudi.lingko.ui.components.ErrorState
import com.aljaroudi.lingko.ui.components.ErrorSeverity
import com.aljaroudi.lingko.ui.translation.components.LanguageSelectionSheet
import com.aljaroudi.lingko.ui.translation.components.TranslationResultCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TranslationScreen(
    onNavigateToHistory: () -> Unit,
    onNavigateToImageTranslation: () -> Unit,
    onTextExtractedCallback: ((String) -> Unit) -> Unit = {},
    viewModel: TranslationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showLanguageSelection by remember { mutableStateOf(false) }

    // Register the callback for extracted text
    LaunchedEffect(Unit) {
        onTextExtractedCallback { text ->
            viewModel.setText(text)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        stringResource(R.string.title_translation),
                        modifier = Modifier.semantics { heading() }
                    ) 
                },
                actions = {
                    IconButton(onClick = onNavigateToHistory) {
                        Icon(Icons.Default.History, contentDescription = stringResource(R.string.cd_history))
                    }
                    IconButton(onClick = { showLanguageSelection = true }) {
                        Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.cd_select_languages))
                    }
                }
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = onNavigateToImageTranslation) {
                Icon(Icons.Default.Image, contentDescription = stringResource(R.string.cd_translate_from_image))
            }
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
        ) {
            // Input field
            OutlinedTextField(
                value = uiState.inputText,
                onValueChange = viewModel::onTextChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                placeholder = { Text(stringResource(R.string.placeholder_enter_text)) },
                minLines = 3,
                maxLines = 6,
                supportingText = {
                    uiState.sourceLanguage?.let { detected ->
                        Text(stringResource(R.string.label_detected, detected.language.displayName))
                    }
                }
            )

            // Selected languages display
            AnimatedVisibility(
                visible = uiState.selectedTargetLanguages.isNotEmpty(),
                enter = fadeIn() + slideInVertically(),
                exit = fadeOut() + slideOutVertically()
            ) {
                Text(
                    text = stringResource(R.string.label_translating_to, uiState.selectedTargetLanguages.size),
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // Romanization toggle
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = stringResource(R.string.label_show_romanization),
                    style = MaterialTheme.typography.bodyMedium
                )
                Switch(
                    checked = uiState.showRomanization,
                    onCheckedChange = { viewModel.toggleRomanization() }
                )
            }

            HorizontalDivider()

            // Translation results area with crossfade animation
            Crossfade(
                targetState = when {
                    uiState.isTranslating -> TranslationState.Loading
                    uiState.error != null -> TranslationState.Error
                    uiState.translations.isNotEmpty() -> TranslationState.Results
                    else -> TranslationState.Empty
                },
                label = "translation_state"
            ) { state ->
                when (state) {
                    TranslationState.Loading -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    }
                    TranslationState.Error -> {
                        ErrorState(
                            title = stringResource(R.string.error_translation_failed),
                            message = uiState.error!!,
                            severity = ErrorSeverity.Error,
                            onRetry = { viewModel.retryTranslation() },
                            onDismiss = { viewModel.clearError() },
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                    TranslationState.Results -> {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(vertical = 8.dp)
                        ) {
                            items(
                                items = uiState.translations,
                                key = { it.id }
                            ) { result ->
                                TranslationResultCard(
                                    result = result,
                                    showRomanization = uiState.showRomanization,
                                    onSpeak = { viewModel.speak(result) },
                                    onCopy = { viewModel.copyToClipboard(result) }
                                )
                            }
                        }
                    }
                    TranslationState.Empty -> {
                        EmptyState(
                            icon = Icons.Default.Translate,
                            title = stringResource(R.string.empty_translation_title),
                            message = stringResource(R.string.empty_translation_message),
                            modifier = Modifier.fillMaxSize()
                        )
                    }
                }
            }
        }
    }

    if (showLanguageSelection) {
        LanguageSelectionSheet(
            selectedLanguages = uiState.selectedTargetLanguages,
            onLanguageToggle = viewModel::toggleLanguage,
            onDismiss = { showLanguageSelection = false }
        )
    }
}

private enum class TranslationState {
    Loading, Error, Results, Empty
}
