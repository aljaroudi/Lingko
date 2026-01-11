package com.aljaroudi.lingko.ui.tags

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import com.aljaroudi.lingko.domain.model.Tag

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TagEditorDialog(
    availableTags: List<Tag>,
    selectedTags: List<Tag>,
    onTagsChanged: (List<Tag>) -> Unit,
    onDismiss: () -> Unit
) {
    var currentSelectedTags by remember { mutableStateOf(selectedTags) }
    
    Dialog(onDismissRequest = onDismiss) {
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Text(
                    text = "Manage Tags",
                    style = MaterialTheme.typography.titleLarge,
                    modifier = Modifier.padding(bottom = 16.dp)
                )
                
                if (availableTags.isEmpty()) {
                    Text(
                        text = "No tags available",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 16.dp)
                    )
                } else {
                    LazyColumn(
                        modifier = Modifier
                            .weight(1f, fill = false)
                            .heightIn(max = 400.dp)
                    ) {
                        items(availableTags) { tag ->
                            val isSelected = currentSelectedTags.any { it.id == tag.id }
                            
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable {
                                        currentSelectedTags = if (isSelected) {
                                            currentSelectedTags.filter { it.id != tag.id }
                                        } else {
                                            currentSelectedTags + tag
                                        }
                                    }
                                    .padding(vertical = 8.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Checkbox(
                                    checked = isSelected,
                                    onCheckedChange = { checked ->
                                        currentSelectedTags = if (checked) {
                                            currentSelectedTags + tag
                                        } else {
                                            currentSelectedTags.filter { it.id != tag.id }
                                        }
                                    }
                                )
                                
                                Spacer(modifier = Modifier.width(8.dp))
                                
                                TagChip(
                                    tag = tag,
                                    modifier = Modifier.weight(1f)
                                )
                                
                                if (isSelected) {
                                    Icon(
                                        imageVector = Icons.Default.Check,
                                        contentDescription = "Selected",
                                        tint = MaterialTheme.colorScheme.primary,
                                        modifier = Modifier.padding(start = 8.dp)
                                    )
                                }
                            }
                        }
                    }
                }
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    TextButton(onClick = onDismiss) {
                        Text("Cancel")
                    }
                    
                    Spacer(modifier = Modifier.width(8.dp))
                    
                    Button(
                        onClick = {
                            onTagsChanged(currentSelectedTags)
                            onDismiss()
                        }
                    ) {
                        Text("Save")
                    }
                }
            }
        }
    }
}
