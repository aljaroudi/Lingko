package com.aljaroudi.lingko.ui.translation

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.Mic
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.SwapVert
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aljaroudi.lingko.R
import com.aljaroudi.lingko.domain.model.Language
import com.aljaroudi.lingko.ui.components.ErrorState
import com.aljaroudi.lingko.ui.components.ErrorSeverity
import com.aljaroudi.lingko.ui.theme.LingkoTheme
import com.aljaroudi.lingko.ui.translation.components.LanguageDropdown
import com.aljaroudi.lingko.ui.translation.components.LanguageSelectionSheet

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

    LaunchedEffect(Unit) {
        onTextExtractedCallback { text -> viewModel.setText(text) }
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
            // Error banner
            if (uiState.error != null) {
                ErrorState(
                    title = stringResource(R.string.error_translation_failed),
                    message = uiState.error!!,
                    severity = ErrorSeverity.Error,
                    onRetry = { viewModel.retryTranslation() },
                    onDismiss = { viewModel.clearError() },
                    modifier = Modifier.fillMaxWidth()
                )
            }

            TwoPanelInputCard(
                uiState = uiState,
                onTextChange = viewModel::onTextChange,
                onSourceSelected = { lang ->
                    if (lang == null) viewModel.clearManualSourceLanguage()
                    else viewModel.setManualSourceLanguage(lang)
                },
                onTargetSelected = viewModel::onTargetLanguageSelected,
                onSwap = viewModel::swap,
                modifier = Modifier.weight(1f)
            )
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

@Composable
private fun TwoPanelInputCard(
    uiState: TranslationUiState,
    onTextChange: (String) -> Unit,
    onSourceSelected: (Language?) -> Unit,
    onTargetSelected: (Language) -> Unit,
    onSwap: () -> Unit,
    modifier: Modifier = Modifier
) {
    val accent = MaterialTheme.colorScheme.tertiary
    val sortedTargetOptions = uiState.selectedTargetLanguages
        .filter { it != uiState.effectiveSourceLanguage }
        .sortedBy { it.displayName }
    val sortedSourceOptions: List<Language?> = listOf(null) +
        uiState.selectedTargetLanguages
            .filter { it != uiState.selectedTargetLanguage }
            .sortedBy { it.displayName }

    val sourceLabel = uiState.manualSourceLanguage?.displayName
        ?: uiState.sourceLanguage?.language?.displayName
        ?: stringResource(R.string.label_auto_detect)

    val targetLabel = uiState.selectedTargetLanguage?.displayName
        ?: stringResource(R.string.label_unknown_language)

    Column(modifier = modifier.fillMaxSize()) {
        // Source panel
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                LanguageDropdown(
                    label = sourceLabel,
                    options = sortedSourceOptions,
                    selectedLanguage = uiState.manualSourceLanguage,
                    onSelect = onSourceSelected,
                    accent = false
                )
                Spacer(modifier = Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Default.Mic,
                    contentDescription = stringResource(R.string.cd_voice_input),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.4f),
                    modifier = Modifier.padding(end = 8.dp)
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            BasicTextField(
                value = uiState.inputText,
                onValueChange = onTextChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 80.dp, max = 200.dp),
                textStyle = TextStyle(
                    color = MaterialTheme.colorScheme.onSurface,
                    fontSize = MaterialTheme.typography.bodyLarge.fontSize
                ),
                cursorBrush = SolidColor(MaterialTheme.colorScheme.primary),
                decorationBox = { inner ->
                    if (uiState.inputText.isEmpty()) {
                        Text(
                            text = stringResource(R.string.placeholder_enter_text),
                            style = MaterialTheme.typography.bodyLarge,
                            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                        )
                    }
                    inner()
                }
            )
        }

        // Swap divider
        Box(
            modifier = Modifier.fillMaxWidth(),
            contentAlignment = Alignment.Center
        ) {
            HorizontalDivider()
            FilledTonalIconButton(
                onClick = onSwap,
                modifier = Modifier.size(36.dp)
            ) {
                Icon(
                    imageVector = Icons.Default.SwapVert,
                    contentDescription = stringResource(R.string.cd_swap_languages),
                    modifier = Modifier.size(18.dp)
                )
            }
        }

        // Target panel
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (sortedTargetOptions.isNotEmpty()) {
                    LanguageDropdown(
                        label = targetLabel,
                        options = sortedTargetOptions,
                        selectedLanguage = uiState.selectedTargetLanguage,
                        onSelect = { lang -> lang?.let { onTargetSelected(it) } },
                        accent = true
                    )
                } else {
                    Text(
                        text = targetLabel,
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = accent,
                        modifier = Modifier.padding(horizontal = 8.dp, vertical = 10.dp)
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
                Icon(
                    imageVector = Icons.Default.Mic,
                    contentDescription = stringResource(R.string.cd_voice_input),
                    tint = accent.copy(alpha = 0.4f),
                    modifier = Modifier.padding(end = 8.dp)
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            Box(modifier = Modifier.fillMaxWidth().heightIn(min = 60.dp)) {
                when {
                    uiState.isTranslating -> CircularProgressIndicator(modifier = Modifier.size(24.dp))
                    uiState.translation != null -> Text(
                        text = uiState.translation.translation,
                        style = MaterialTheme.typography.bodyLarge,
                        color = accent
                    )
                }
            }
        }

        Spacer(modifier = Modifier.weight(1f))
    }
}

@Preview(showBackground = true)
@Composable
private fun TranslationScreenPreview() {
    LingkoTheme {
        TwoPanelInputCard(
            uiState = TranslationUiState(
                inputText = "Hello, world!",
                manualSourceLanguage = Language.ENGLISH,
                selectedTargetLanguage = Language.RUSSIAN
            ),
            onTextChange = {},
            onSourceSelected = {},
            onTargetSelected = {},
            onSwap = {}
        )
    }
}
