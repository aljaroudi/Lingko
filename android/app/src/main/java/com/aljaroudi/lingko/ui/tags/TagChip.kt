package com.aljaroudi.lingko.ui.tags

import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import com.aljaroudi.lingko.domain.model.Tag

@Composable
fun TagChip(
    tag: Tag,
    modifier: Modifier = Modifier,
    onRemove: (() -> Unit)? = null
) {
    val backgroundColor = tag.color?.let { parseColor(it) } ?: MaterialTheme.colorScheme.secondaryContainer
    val contentColor = if (isColorDark(backgroundColor)) Color.White else Color.Black
    
    FilterChip(
        selected = false,
        onClick = { onRemove?.invoke() },
        label = {
            Text(
                text = tag.name,
                style = MaterialTheme.typography.labelSmall,
                color = contentColor
            )
        },
        trailingIcon = if (onRemove != null) {
            {
                Icon(
                    imageVector = Icons.Default.Close,
                    contentDescription = "Remove tag",
                    modifier = Modifier.size(16.dp),
                    tint = contentColor
                )
            }
        } else null,
        colors = FilterChipDefaults.filterChipColors(
            containerColor = backgroundColor,
            labelColor = contentColor,
            iconColor = contentColor
        ),
        modifier = modifier
    )
}

private fun parseColor(hexColor: String): Color {
    return try {
        val cleanHex = hexColor.removePrefix("#")
        val colorInt = cleanHex.toLong(16)
        when (cleanHex.length) {
            6 -> Color(0xFF000000 or colorInt)
            8 -> Color(colorInt)
            else -> Color.Gray
        }
    } catch (e: Exception) {
        Color.Gray
    }
}

private fun isColorDark(color: Color): Boolean {
    val luminance = 0.299 * color.red + 0.587 * color.green + 0.114 * color.blue
    return luminance < 0.5
}
