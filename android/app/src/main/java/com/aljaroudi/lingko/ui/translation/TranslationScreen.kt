package com.aljaroudi.lingko.ui.translation

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aljaroudi.lingko.ui.translation.components.LanguageSelectionSheet
import com.aljaroudi.lingko.ui.translation.components.TranslationResultCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TranslationScreen(
    viewModel: TranslationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showLanguageSelection by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Lingko") },
                actions = {
                    IconButton(onClick = { showLanguageSelection = true }) {
                        Icon(Icons.Default.Settings, contentDescription = "Select languages")
                    }
                }
            )
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
                placeholder = { Text("Enter text to translate") },
                minLines = 3,
                maxLines = 6,
                supportingText = {
                    uiState.sourceLanguage?.let { detected ->
                        Text("Detected: ${detected.language.displayName}")
                    }
                }
            )

            // Selected languages display
            if (uiState.selectedTargetLanguages.isNotEmpty()) {
                Text(
                    text = "Translating to: ${uiState.selectedTargetLanguages.size} language(s)",
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            HorizontalDivider()

            // Translation results area
            when {
                uiState.isTranslating -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator()
                    }
                }
                uiState.error != null -> {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp),
                        contentAlignment = Alignment.TopStart
                    ) {
                        Text(
                            text = uiState.error!!,
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
                uiState.translations.isNotEmpty() -> {
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
                                onSpeak = { viewModel.speak(result) },
                                onCopy = { viewModel.copyToClipboard(result) }
                            )
                        }
                    }
                }
                else -> {
                    Box(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp),
                        contentAlignment = Alignment.TopStart
                    ) {
                        Text(
                            text = "Enter text above to see translation",
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
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
