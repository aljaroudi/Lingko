package com.aljaroudi.lingko.ui.history

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.DeleteSweep
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.aljaroudi.lingko.R
import com.aljaroudi.lingko.ui.components.EmptyState
import com.aljaroudi.lingko.ui.history.components.HistoryItem

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(
    onNavigateBack: () -> Unit,
    viewModel: HistoryViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.title_history)) },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.cd_back)
                        )
                    }
                },
                actions = {
                    if (uiState.translationGroups.isNotEmpty()) {
                        IconButton(onClick = { viewModel.clearAll() }) {
                            Icon(
                                imageVector = Icons.Default.DeleteSweep,
                                contentDescription = stringResource(R.string.cd_clear_all)
                            )
                        }
                    }
                }
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
        ) {
            // Search bar
            OutlinedTextField(
                value = uiState.searchQuery,
                onValueChange = viewModel::onSearchChange,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                placeholder = { Text(stringResource(R.string.placeholder_search_translations)) },
                singleLine = true
            )

            // Content with crossfade animation
            Crossfade(
                targetState = when {
                    uiState.isLoading -> HistoryState.Loading
                    uiState.translationGroups.isEmpty() && uiState.searchQuery.isBlank() -> HistoryState.EmptyHistory
                    uiState.translationGroups.isEmpty() && uiState.searchQuery.isNotBlank() -> HistoryState.EmptySearch
                    else -> HistoryState.Results
                },
                label = "history_state"
            ) { state ->
                when (state) {
                    HistoryState.Loading -> {
                        Box(
                            modifier = Modifier.fillMaxSize(),
                            contentAlignment = Alignment.Center
                        ) {
                            CircularProgressIndicator()
                        }
                    }
                    HistoryState.EmptyHistory -> {
                        EmptyState(
                            icon = Icons.Default.History,
                            title = stringResource(R.string.empty_history_title),
                            message = stringResource(R.string.empty_history_message),
                            modifier = Modifier.fillMaxSize(),
                            iconTint = MaterialTheme.colorScheme.secondary
                        )
                    }
                    HistoryState.EmptySearch -> {
                        EmptyState(
                            icon = Icons.Default.Search,
                            title = stringResource(R.string.empty_search_title),
                            message = stringResource(R.string.empty_search_message, uiState.searchQuery),
                            modifier = Modifier.fillMaxSize(),
                            iconTint = MaterialTheme.colorScheme.tertiary
                        )
                    }
                    HistoryState.Results -> {
                        LazyColumn(
                            modifier = Modifier.fillMaxSize(),
                            contentPadding = PaddingValues(vertical = 8.dp)
                        ) {
                            items(
                                items = uiState.translationGroups,
                                key = { it.groupId }
                            ) { group ->
                                HistoryItem(
                                    group = group,
                                    onFavoriteToggle = { viewModel.toggleFavorite(group.groupId) },
                                    onDelete = { viewModel.delete(group.groupId) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

private enum class HistoryState {
    Loading, EmptyHistory, EmptySearch, Results
}
