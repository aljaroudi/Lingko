package com.aljaroudi.lingko.ui.components

import androidx.compose.foundation.layout.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Error
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/**
 * Reusable error state component with error icon, title, message, and retry button.
 */
@Composable
fun ErrorState(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    severity: ErrorSeverity = ErrorSeverity.Error,
    onRetry: (() -> Unit)? = null,
    onDismiss: (() -> Unit)? = null
) {
    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            colors = CardDefaults.cardColors(
                containerColor = severity.backgroundColor
            )
        ) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(24.dp)
            ) {
                // Icon
                Icon(
                    imageVector = severity.icon,
                    contentDescription = null,
                    modifier = Modifier.size(48.dp),
                    tint = severity.color
                )

                // Title
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleMedium,
                    color = severity.onBackgroundColor,
                    textAlign = TextAlign.Center
                )

                // Message
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = severity.onBackgroundColor.copy(alpha = 0.8f),
                    textAlign = TextAlign.Center
                )

                // Actions
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    onRetry?.let { retry ->
                        Button(onClick = retry) {
                            Text("Retry")
                        }
                    }

                    onDismiss?.let { dismiss ->
                        TextButton(onClick = dismiss) {
                            Text("Dismiss")
                        }
                    }
                }
            }
        }
    }
}

/**
 * Error banner that appears at the top of the screen.
 */
@Composable
fun ErrorBanner(
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    severity: ErrorSeverity = ErrorSeverity.Error,
    onRetry: (() -> Unit)? = null,
    onDismiss: () -> Unit
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .padding(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = severity.backgroundColor
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Icon
            Icon(
                imageVector = severity.icon,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = severity.color
            )

            // Content
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(
                    text = title,
                    style = MaterialTheme.typography.titleSmall,
                    color = severity.onBackgroundColor
                )
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = severity.onBackgroundColor.copy(alpha = 0.8f)
                )
            }

            // Actions
            Row(
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                onRetry?.let { retry ->
                    FilledTonalButton(
                        onClick = retry,
                        contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                    ) {
                        Text("Retry", style = MaterialTheme.typography.labelSmall)
                    }
                }

                IconButton(onClick = onDismiss) {
                    Icon(
                        imageVector = Icons.Default.Info,
                        contentDescription = "Dismiss",
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }
}

/**
 * Error severity levels.
 */
enum class ErrorSeverity {
    Error,
    Warning,
    Info;

    val icon: ImageVector
        @Composable
        get() = when (this) {
            Error -> Icons.Default.Error
            Warning -> Icons.Default.Warning
            Info -> Icons.Default.Info
        }

    val color: Color
        @Composable
        get() = when (this) {
            Error -> MaterialTheme.colorScheme.error
            Warning -> Color(0xFFFF9800) // Orange
            Info -> MaterialTheme.colorScheme.primary
        }

    val backgroundColor: Color
        @Composable
        get() = when (this) {
            Error -> MaterialTheme.colorScheme.errorContainer
            Warning -> Color(0xFFFFF3E0) // Light orange
            Info -> MaterialTheme.colorScheme.primaryContainer
        }

    val onBackgroundColor: Color
        @Composable
        get() = when (this) {
            Error -> MaterialTheme.colorScheme.onErrorContainer
            Warning -> Color(0xFF5D4037) // Dark brown
            Info -> MaterialTheme.colorScheme.onPrimaryContainer
        }
}
