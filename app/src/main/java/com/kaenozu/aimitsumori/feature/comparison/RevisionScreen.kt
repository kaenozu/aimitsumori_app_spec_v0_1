package com.kaenozu.aimitsumori.feature.comparison

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
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.kaenozu.aimitsumori.domain.model.Project
import java.text.NumberFormat
import java.util.Locale

data class RevisionGroup(
    val contractorName: String,
    val revisions: List<RevisionInfo>,
)

data class RevisionInfo(
    val revisionNumber: Int,
    val totalAmountYen: Long?,
    val itemCount: Int,
    val createdAtEpochMillis: Long,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RevisionScreen(
    project: Project,
    onBack: () -> Unit,
) {
    val groups = project.quotes
        .groupBy { it.contractorName }
        .map { (name, quotes) ->
            RevisionGroup(
                contractorName = name,
                revisions = quotes.mapIndexed { index, q ->
                    RevisionInfo(
                        revisionNumber = index + 1,
                        totalAmountYen = q.totalAmountYen,
                        itemCount = q.lineItems.size,
                        createdAtEpochMillis = q.createdAtEpochMillis,
                    )
                },
            )
        }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("改訂履歴") },
                navigationIcon = {
                    OutlinedButton(onClick = onBack) { Text("戻る") }
                },
            )
        },
    ) { padding ->
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            items(groups, key = { it.contractorName }) { group ->
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            group.contractorName,
                            style = MaterialTheme.typography.titleMedium,
                        )
                        Spacer(Modifier.height(8.dp))
                        group.revisions.forEachIndexed { index, rev ->
                            if (index > 0) HorizontalDivider(Modifier.padding(vertical = 4.dp))
                            RevisionRow(rev, group.revisions.firstOrNull())
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RevisionRow(rev: RevisionInfo, first: RevisionInfo?) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("第${rev.revisionNumber}版", style = MaterialTheme.typography.bodyLarge)
            Text(formatYen(rev.totalAmountYen))
        }
        if (first != null && rev.revisionNumber > 1 && first.totalAmountYen != null && rev.totalAmountYen != null) {
            val diff = rev.totalAmountYen - first.totalAmountYen
            Text(
                text = "初版比: ${if (diff >= 0) "+" else ""}${formatYen(diff)}",
                color = if (diff != 0L) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurface,
            )
        }
        Text(
            "項目数: ${rev.itemCount}",
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

private fun formatYen(value: Long?): String =
    value?.let { "${NumberFormat.getNumberInstance(Locale.JAPAN).format(it)}円" } ?: "不明"
