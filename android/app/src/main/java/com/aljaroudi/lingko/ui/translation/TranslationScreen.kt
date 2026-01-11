package com.aljaroudi.lingko.ui.translation

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TranslationScreen(
    viewModel: TranslationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Lingko") }
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

            // Target language display
            Text(
                text = "Translating to: ${uiState.selectedTargetLanguage.nativeName}",
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            HorizontalDivider()

            // Translation result area
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(16.dp),
                contentAlignment = if (uiState.isTranslating) Alignment.Center else Alignment.TopStart
            ) {
                when {
                    uiState.isTranslating -> {
                        CircularProgressIndicator()
                    }
                    uiState.error != null -> {
                        Text(
                            text = uiState.error!!,
                            color = MaterialTheme.colorScheme.error,
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                    uiState.translationResult != null -> {
                        Card(
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(
                                modifier = Modifier.padding(16.dp)
                            ) {
                                Text(
                                    text = uiState.selectedTargetLanguage.nativeName,
                                    style = MaterialTheme.typography.titleMedium,
                                    color = MaterialTheme.colorScheme.primary
                                )

                                Spacer(modifier = Modifier.height(8.dp))

                                Text(
                                    text = uiState.translationResult!!,
                                    style = MaterialTheme.typography.headlineSmall
                                )
                            }
                        }
                    }
                    else -> {
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
}
