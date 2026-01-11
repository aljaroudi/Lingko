package com.aljaroudi.lingko.ui.image

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Image
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aljaroudi.lingko.ui.image.components.ImageWithTextOverlay
import com.aljaroudi.lingko.ui.image.components.TranslationBottomSheet

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImageTranslationScreen(
    onNavigateBack: () -> Unit,
    onTextExtracted: (String) -> Unit,
    viewModel: ImageTranslationViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    // Photo Picker launcher
    val launcher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        uri?.let { viewModel.processImage(it) }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Translate from Image") },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back")
                    }
                }
            )
        },
        floatingActionButton = {
            if (uiState.textBlocks.isNotEmpty()) {
                ExtendedFloatingActionButton(
                    onClick = {
                        val allText = viewModel.getAllTextForTranslation()
                        onTextExtracted(allText)
                        onNavigateBack()
                    },
                    icon = { Icon(Icons.Default.Image, contentDescription = null) },
                    text = { Text("Translate All") }
                )
            }
        }
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            when {
                uiState.isProcessing -> {
                    // Processing state
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        CircularProgressIndicator()
                        Text(
                            text = "Extracting text...",
                            modifier = Modifier.padding(top = 16.dp),
                            style = MaterialTheme.typography.bodyLarge
                        )
                    }
                }
                uiState.imageUri != null && uiState.textBlocks.isNotEmpty() -> {
                    // Success state - show image with text overlays
                    ImageWithTextOverlay(
                        imageUri = uiState.imageUri!!,
                        textBlocks = uiState.textBlocks,
                        highlightedBlockId = uiState.highlightedBlockId,
                        onTextBlockTapped = { blockId ->
                            viewModel.selectTextBlock(blockId)
                        },
                        modifier = Modifier.fillMaxSize()
                    )

                    // Info card at bottom
                    Card(
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .fillMaxWidth()
                            .padding(16.dp),
                        colors = CardDefaults.cardColors(
                            containerColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(16.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "${uiState.textBlocks.size} text region(s) detected",
                                style = MaterialTheme.typography.bodyMedium
                            )
                            FilledTonalButton(
                                onClick = {
                                    launcher.launch(
                                        PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                    )
                                }
                            ) {
                                Icon(Icons.Default.PhotoLibrary, contentDescription = null)
                                Spacer(modifier = Modifier.width(4.dp))
                                Text("New Image")
                            }
                        }
                    }
                }
                else -> {
                    // Initial state or error state
                    Column(
                        modifier = Modifier
                            .fillMaxSize()
                            .padding(16.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center
                    ) {
                        Icon(
                            Icons.Default.Image,
                            contentDescription = null,
                            modifier = Modifier.size(120.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )

                        Text(
                            text = "Select an image to extract text",
                            modifier = Modifier.padding(16.dp),
                            style = MaterialTheme.typography.titleMedium
                        )

                        Button(
                            onClick = {
                                launcher.launch(
                                    PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                                )
                            }
                        ) {
                            Icon(Icons.Default.PhotoLibrary, contentDescription = null)
                            Spacer(modifier = Modifier.width(8.dp))
                            Text("Select Image")
                        }

                        // Error message
                        uiState.error?.let { error ->
                            Spacer(modifier = Modifier.height(16.dp))
                            Text(
                                text = error,
                                color = MaterialTheme.colorScheme.error,
                                style = MaterialTheme.typography.bodyMedium
                            )
                        }
                    }
                }
            }
        }

        // Translation bottom sheet
        if (uiState.showTranslationSheet && uiState.selectedTextBlock != null) {
            TranslationBottomSheet(
                selectedTextBlock = uiState.selectedTextBlock!!,
                translations = uiState.translations,
                isTranslating = uiState.isTranslating,
                showRomanization = true,
                onDismiss = { viewModel.dismissTranslationSheet() },
                onSpeak = { result -> viewModel.speak(result) },
                onCopy = { result -> viewModel.copyToClipboard(result) },
                onTranslateAll = {
                    val allText = viewModel.getAllTextForTranslation()
                    onTextExtracted(allText)
                    onNavigateBack()
                }
            )
        }
    }
}
