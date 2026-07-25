package com.kaenozu.aimitsumori.feature.project

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kaenozu.aimitsumori.feature.project.ChecklistUiState.CategoryState

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ChecklistScreen(
    viewModel: ChecklistViewModel,
    onBack: () -> Unit,
    onSaved: () -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(title = { Text("工事条件チェックリスト") })
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            items(uiState.categories, key = CategoryState::id) { category ->
                CategorySection(
                    category = category,
                    onRequirementTypeChange = { itemId, type ->
                        viewModel.setRequirementType(itemId, type)
                    },
                    onSpecificationChange = { itemId, value ->
                        viewModel.setSpecification(itemId, value)
                    },
                    onQuantityChange = { itemId, value ->
                        viewModel.setQuantity(itemId, value)
                    },
                )
            }

            item {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Button(
                        onClick = onBack,
                        modifier = Modifier.weight(1f),
                        enabled = !uiState.isSaving,
                    ) {
                        Text("戻る")
                    }
                    Button(
                        onClick = { viewModel.save(onSaved) },
                        modifier = Modifier.weight(1f),
                        enabled = !uiState.isSaving,
                    ) {
                        Text(if (uiState.isSaving) "保存中…" else "保存して比較へ")
                    }
                }
                Spacer(Modifier.height(24.dp))
            }
        }
    }
}

@Composable
private fun CategorySection(
    category: CategoryState,
    onRequirementTypeChange: (String, String) -> Unit,
    onSpecificationChange: (String, String) -> Unit,
    onQuantityChange: (String, String) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(
                text = category.nameJa,
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(Modifier.height(12.dp))

            category.items.forEach { item ->
                ChecklistItemRow(
                    item = item,
                    onRequirementTypeChange = { onRequirementTypeChange(item.id, it) },
                    onSpecificationChange = { onSpecificationChange(item.id, it) },
                    onQuantityChange = { onQuantityChange(item.id, it) },
                )
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun ChecklistItemRow(
    item: ItemState,
    onRequirementTypeChange: (String) -> Unit,
    onSpecificationChange: (String) -> Unit,
    onQuantityChange: (String) -> Unit,
) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = item.nameJa,
            style = MaterialTheme.typography.bodyLarge,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            listOf("unset" to "未設定", "required" to "必須", "optional" to "任意", "excluded" to "不要").forEach { (value, label) ->
                FilterChip(
                    selected = item.requirementType == value,
                    onClick = { onRequirementTypeChange(value) },
                    label = { Text(label) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = when (value) {
                            "required" -> MaterialTheme.colorScheme.primaryContainer
                            "excluded" -> MaterialTheme.colorScheme.errorContainer
                            else -> MaterialTheme.colorScheme.secondaryContainer
                        },
                    ),
                )
            }
        }
        if (item.specification.isNotEmpty() || item.quantity.isNotEmpty()) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                OutlinedTextField(
                    value = item.quantity,
                    onValueChange = onQuantityChange,
                    label = { Text("数量") },
                    singleLine = true,
                    modifier = Modifier.weight(1f),
                )
                OutlinedTextField(
                    value = item.specification,
                    onValueChange = onSpecificationChange,
                    label = { Text("仕様・備考") },
                    singleLine = true,
                    modifier = Modifier.weight(2f),
                )
            }
        }
    }
}
