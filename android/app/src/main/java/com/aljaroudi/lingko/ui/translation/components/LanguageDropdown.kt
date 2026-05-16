package com.aljaroudi.lingko.ui.translation.components

import androidx.compose.foundation.layout.Box
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.UnfoldMore
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import com.aljaroudi.lingko.R
import com.aljaroudi.lingko.domain.model.Language

@Composable
fun LanguageDropdown(
    label: String,
    options: List<Language?>,
    selectedLanguage: Language?,
    onSelect: (Language?) -> Unit,
    accent: Boolean = false,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }
    val color = if (accent) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.onSurface

    Box(modifier = modifier) {
        TextButton(onClick = { expanded = true }) {
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                color = color
            )
            Icon(
                imageVector = Icons.Default.UnfoldMore,
                contentDescription = null,
                tint = color
            )
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            options.forEach { language ->
                val itemLabel = language?.displayName ?: stringResource(R.string.label_auto_detect)
                DropdownMenuItem(
                    text = { Text(itemLabel) },
                    onClick = {
                        expanded = false
                        onSelect(language)
                    }
                )
            }
        }
    }
}
