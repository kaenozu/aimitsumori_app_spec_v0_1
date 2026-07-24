package com.kaenozu.aimitsumori.feature.review

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
import androidx.compose.material3.FilterChip
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun ReviewScreen(
    viewModel: ReviewViewModel,
    onBack: () -> Unit,
    onComplete: () -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { TopAppBar(title = { Text("確認") }) },
    ) { padding ->
        if (uiState.isComplete) {
            ReviewCompleteContent(
                onContinue = onComplete,
                modifier = Modifier.padding(padding),
            )
            return@Scaffold
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
        ) {
            val total = uiState.items.size
            val done = uiState.items.count { it.status != ReviewStatus.PENDING }
            LinearProgressIndicator(
                progress = { if (total > 0) done.toFloat() / total else 0f },
                modifier = Modifier.fillMaxWidth(),
            )
            Text(
                "${done}/${total} 件確認済み",
                style = MaterialTheme.typography.bodySmall,
            )
            Spacer(Modifier.height(16.dp))

            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(uiState.items, key = ReviewItem::id) { item ->
                    ReviewItemCard(
                        item = item,
                        onStatusChange = { viewModel.setStatus(item.id, it) },
                        onValueChange = { viewModel.setCorrectedValue(item.id, it) },
                    )
                }
            }

            Spacer(Modifier.height(12.dp))
            Button(
                onClick = { viewModel.nextItem() },
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("確認完了")
            }
            OutlinedButton(
                onClick = onBack,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("戻る")
            }
        }
    }
}

@Composable
private fun ReviewItemCard(
    item: ReviewItem,
    onStatusChange: (ReviewStatus) -> Unit,
    onValueChange: (String) -> Unit,
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(item.vendorName, style = MaterialTheme.typography.labelMedium)
            Spacer(Modifier.height(4.dp))
            Text(item.question, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(8.dp))

            if (item.sourceText.isNotBlank()) {
                Text(
                    "原文: ${item.sourceText}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(8.dp))
            }

            if (item.type == ReviewType.TOTAL_AMOUNT) {
                OutlinedTextField(
                    value = item.correctedValue,
                    onValueChange = onValueChange,
                    label = { Text("正しい金額") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                Spacer(Modifier.height(8.dp))
            }

            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                listOf(
                    ReviewStatus.CORRECT to "正しい",
                    ReviewStatus.FIXED to "修正",
                    ReviewStatus.UNKNOWN to "不明",
                    ReviewStatus.ASK_VENDOR to "業者へ確認",
                    ReviewStatus.NOT_APPLICABLE to "対象外",
                ).forEach { (status, label) ->
                    FilterChip(
                        selected = item.status == status,
                        onClick = { onStatusChange(status) },
                        label = { Text(label) },
                    )
                }
            }
        }
    }
}

@Composable
private fun ReviewCompleteContent(
    onContinue: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text("確認が完了しました", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(16.dp))
        Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) {
            Text("比較画面へ")
        }
    }
}
