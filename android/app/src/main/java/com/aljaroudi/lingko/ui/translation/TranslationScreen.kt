package com.aljaroudi.lingko.ui.translation

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aljaroudi.lingko.R
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.ui.components.EmptyState
import com.aljaroudi.lingko.ui.components.ErrorState
import com.aljaroudi.lingko.ui.components.ErrorSeverity
import com.aljaroudi.lingko.ui.translation.components.LanguageSelectionSheet
import com.aljaroudi.lingko.ui.translation.components.SourceLanguageSelectionDialog
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
    var showSourceLanguageSelection by remember { mutableStateOf(false) }

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
            // Source language selector
            SourceLanguageChipRow(
                availableLanguages = uiState.selectedTargetLanguages.sortedBy { it.displayName },
                selectedLanguage = uiState.manualSourceLanguage,
                onLanguageSelected = viewModel::setManualSourceLanguage,
                onAutoSelected = viewModel::clearManualSourceLanguage,
                modifier = Modifier.fillMaxWidth()
            )

            // Input field
            TextField(
                value = uiState.inputText,
                onValueChange = viewModel::onTextChange,
                modifier = Modifier
                    .fillMaxWidth(),
                placeholder = { Text(stringResource(R.string.placeholder_enter_text)) },
                minLines = 3,
                maxLines = 6
            )

            HorizontalDivider()

            // Language selector (only show if languages are selected and text is not empty)
            if (uiState.selectedTargetLanguages.isNotEmpty() && uiState.inputText.isNotBlank()) {
                // Filter out source language from target languages
                val targetLanguages = uiState.selectedTargetLanguages
                    .filter { it != uiState.effectiveSourceLanguage }
                    .sortedBy { it.displayName }

                if (targetLanguages.isNotEmpty()) {
                    LanguageChipRow(
                        languages = targetLanguages,
                        activeLanguage = uiState.activePriorityLanguage,
                        onLanguageSelected = viewModel::setActivePriorityLanguage,
                        modifier = Modifier.fillMaxWidth()
                    )
                    HorizontalDivider()
                }
            }

            // Translation results area with crossfade animation
            Crossfade(
                targetState = when {
                    uiState.isTranslating -> TranslationState.Loading
                    uiState.error != null -> TranslationState.Error
                    uiState.activeTranslation != null -> TranslationState.Results
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
                        // Show only the active priority language's translation
                        uiState.activeTranslation?.let { activeResult ->
                            LazyColumn(
                                modifier = Modifier.fillMaxSize(),
                                contentPadding = PaddingValues(vertical = 8.dp)
                            ) {
                                item {
                                    TranslationResultCard(
                                        result = activeResult,
                                        showRomanization = true,
                                        onSpeak = { viewModel.speak(activeResult) },
                                        onCopy = { viewModel.copyToClipboard(activeResult) }
                                    )
                                }
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
    
    if (showSourceLanguageSelection) {
        SourceLanguageSelectionDialog(
            currentSourceLanguage = uiState.effectiveSourceLanguage,
            detectedLanguages = uiState.possibleSourceLanguages,
            onLanguageSelected = viewModel::setManualSourceLanguage,
            onDismiss = { showSourceLanguageSelection = false }
        )
    }
}

@Composable
private fun SourceLanguageChipRow(
    availableLanguages: List<Language>,
    selectedLanguage: Language?,
    onLanguageSelected: (Language) -> Unit,
    onAutoSelected: () -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier
            .padding(vertical = 12.dp),
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        // Auto option
        item(key = "auto") {
            FilterChip(
                selected = selectedLanguage == null,
                onClick = onAutoSelected,
                label = {
                    Text(
                        text = "Auto",
                        style = MaterialTheme.typography.bodyMedium
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }

        // Language options
        items(
            count = availableLanguages.size,
            key = { index -> availableLanguages[index].code }
        ) { index ->
            val language = availableLanguages[index]
            val isActive = selectedLanguage == language
            FilterChip(
                selected = isActive,
                onClick = { onLanguageSelected(language) },
                label = {
                    Text(
                        text = language.displayName,
                        style = MaterialTheme.typography.bodyMedium
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    }
}

@Composable
private fun LanguageChipRow(
    languages: List<Language>,
    activeLanguage: Language?,
    onLanguageSelected: (Language) -> Unit,
    modifier: Modifier = Modifier
) {
    LazyRow(
        modifier = modifier
            .padding(vertical = 12.dp),
        contentPadding = PaddingValues(horizontal = 16.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        items(
            count = languages.size,
            key = { index -> languages[index].code }
        ) { index ->
            val language = languages[index]
            val isActive = activeLanguage == language
            FilterChip(
                selected = isActive,
                onClick = { onLanguageSelected(language) },
                label = {
                    Text(
                        text = language.displayName,
                        style = MaterialTheme.typography.bodyMedium
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    selectedContainerColor = MaterialTheme.colorScheme.primary,
                    selectedLabelColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    }
}

private enum class TranslationState {
    Loading, Error, Results, Empty
}
