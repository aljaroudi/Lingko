package com.aljaroudi.lingko.ui.components

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/**
 * Reusable empty state component with icon, title, message, and optional action button.
 */
@Composable
fun EmptyState(
    icon: ImageVector,
    title: String,
    message: String,
    modifier: Modifier = Modifier,
    actionButton: EmptyStateAction? = null,
    iconTint: androidx.compose.ui.graphics.Color = MaterialTheme.colorScheme.primary,
    animate: Boolean = true
) {
    val infiniteTransition = rememberInfiniteTransition(label = "empty_state_animation")
    val scale by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = if (animate) 1.1f else 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "scale_animation"
    )

    Box(
        modifier = modifier.fillMaxSize(),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier = Modifier.padding(32.dp)
        ) {
            // Icon with subtle animation
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier
                    .size(80.dp)
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                    },
                tint = iconTint.copy(alpha = 0.6f)
            )

            // Title
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center
            )

            // Message
            Text(
                text = message,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center
            )

            // Optional action button
            actionButton?.let { action ->
                Spacer(modifier = Modifier.height(8.dp))
                Button(
                    onClick = action.onClick,
                    modifier = Modifier.padding(top = 8.dp)
                ) {
                    Icon(
                        imageVector = action.icon,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(action.label)
                }
            }
        }
    }
}

/**
 * Data class for empty state action button.
 */
data class EmptyStateAction(
    val label: String,
    val icon: ImageVector,
    val onClick: () -> Unit
)
