package com.kaenozu.aimitsumori.feature.comparison

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kaenozu.aimitsumori.domain.model.CategoryComparison
import com.kaenozu.aimitsumori.domain.model.ClarificationQuestion
import com.kaenozu.aimitsumori.domain.model.ComparisonCell
import com.kaenozu.aimitsumori.domain.model.ComparisonReport
import com.kaenozu.aimitsumori.domain.model.QuoteSnapshot
import java.text.NumberFormat
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ComparisonScreen(
    viewModel: ComparisonViewModel,
    onBack: () -> Unit,
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("比較") },
                navigationIcon = {
                    OutlinedButton(onClick = onBack) { Text("戻る") }
                },
            )
        },
    ) { padding ->
        when (val state = uiState) {
            ComparisonUiState.Loading -> LoadingContent(Modifier.padding(padding))
            is ComparisonUiState.Error -> ErrorContent(
                message = state.message,
                modifier = Modifier.padding(padding),
            )
            is ComparisonUiState.Ready -> ReportContent(
                report = state.report,
                modifier = Modifier.padding(padding),
            )
        }
    }
}

@Composable
private fun LoadingContent(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator()
    }
}

@Composable
private fun ErrorContent(
    message: String,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxSize().padding(16.dp)) {
        Text(message, color = MaterialTheme.colorScheme.error)
    }
}

@Composable
private fun ReportContent(
    report: ComparisonReport,
    modifier: Modifier = Modifier,
) {
    LazyColumn(
        modifier = modifier.fillMaxSize(),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        item {
            Column(Modifier.padding(horizontal = 16.dp)) {
                Text(report.projectName, style = MaterialTheme.typography.headlineSmall)
                Text(
                    "順位・総合点は付けず、条件差と不明点を確認します。",
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        item {
            SummaryCard(
                lines = report.summaryLines,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }

        item {
            Row(
                modifier = Modifier
                    .horizontalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                report.quoteSnapshots.forEach { snapshot ->
                    QuoteSnapshotCard(snapshot)
                }
            }
        }

        item {
            Text(
                text = "18カテゴリ比較",
                modifier = Modifier.padding(horizontal = 16.dp),
                style = MaterialTheme.typography.titleLarge,
            )
        }

        items(report.categoryComparisons, key = { it.category.id }) { comparison ->
            CategoryComparisonCard(
                comparison = comparison,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }

        item {
            Text(
                text = "確認質問テンプレート (${report.clarificationQuestions.size}件)",
                modifier = Modifier.padding(horizontal = 16.dp),
                style = MaterialTheme.typography.titleLarge,
            )
        }

        items(
            items = report.clarificationQuestions,
            key = ClarificationQuestion::id,
        ) { question ->
            QuestionCard(
                question = question,
                modifier = Modifier.padding(horizontal = 16.dp),
            )
        }

        item { Spacer(Modifier.height(24.dp)) }
    }
}

@Composable
private fun SummaryCard(
    lines: List<String>,
    modifier: Modifier = Modifier,
) {
    Card(modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text("3行サマリー", style = MaterialTheme.typography.titleMedium)
            lines.forEachIndexed { index, line ->
                Text("${index + 1}. $line")
            }
        }
    }
}

@Composable
private fun QuoteSnapshotCard(snapshot: QuoteSnapshot) {
    Card(modifier = Modifier.width(280.dp)) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(snapshot.contractorName, style = MaterialTheme.typography.titleMedium)
            Text("提示総額: ${formatYen(snapshot.totalAmountYen)}")
            Text("見積内: ${snapshot.includedCategoryCount}カテゴリ")
            Text("別途: ${snapshot.separateCategoryNames.ifEmpty { listOf("なし") }.joinToString()}")
            Text("任意: ${snapshot.optionalCategoryNames.ifEmpty { listOf("なし") }.joinToString()}")
            Text("含有不明: ${snapshot.unknownCategoryNames.size}カテゴリ")
            Text("不確実点: ${snapshot.uncertaintyCount}件")
        }
    }
}

@Composable
private fun CategoryComparisonCard(
    comparison: CategoryComparison,
    modifier: Modifier = Modifier,
) {
    Card(modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(
                comparison.category.nameJa,
                style = MaterialTheme.typography.titleMedium,
            )
            Spacer(Modifier.height(8.dp))
            comparison.cells.forEachIndexed { index, cell ->
                ComparisonCellContent(cell)
                if (index != comparison.cells.lastIndex) {
                    HorizontalDivider(Modifier.padding(vertical = 8.dp))
                }
            }
        }
    }
}

@Composable
private fun ComparisonCellContent(cell: ComparisonCell) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(cell.contractorName, style = MaterialTheme.typography.labelLarge)
            AssistChip(
                onClick = {},
                label = { Text(cell.inclusionStatus.labelJa) },
            )
        }
        Text("金額: ${formatYen(cell.amountYen)}")
        Text("数量: ${formatQuantity(cell.quantity, cell.unit)}")
        Text("仕様: ${cell.specification ?: "不明"}")
        if (cell.uncertaintyReasons.isNotEmpty()) {
            Text(
                text = "不明・確認: ${cell.uncertaintyReasons.joinToString(" / ")}",
                color = MaterialTheme.colorScheme.error,
                style = MaterialTheme.typography.bodySmall,
            )
        }
    }
}

@Composable
private fun QuestionCard(
    question: ClarificationQuestion,
    modifier: Modifier = Modifier,
) {
    Card(modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            Text(question.templateKey, style = MaterialTheme.typography.labelMedium)
            Text(question.questionText)
        }
    }
}

private fun formatYen(value: Long?): String =
    value?.let { "${NumberFormat.getNumberInstance(Locale.JAPAN).format(it)}円" } ?: "不明"

private fun formatQuantity(quantity: Double?, unit: String?): String = when {
    quantity == null || unit == null -> "不明"
    quantity % 1.0 == 0.0 -> "${quantity.toLong()} $unit"
    else -> "$quantity $unit"
}
