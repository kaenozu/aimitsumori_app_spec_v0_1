package com.kaenozu.aimitsumori.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun UnlockPrompt(
    onWatchAd: () -> Unit,
    onPurchase: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Text(
                "詳細比較を利用",
                style = MaterialTheme.typography.titleMedium,
            )
            Text(
                "広告を視聴するか、買い切りで全機能を解除します。",
                style = MaterialTheme.typography.bodySmall,
            )
            Spacer(Modifier.height(8.dp))
            Button(
                onClick = onWatchAd,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("広告を視聴して解除")
            }
            OutlinedButton(
                onClick = onPurchase,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("買い切り購入")
            }
        }
    }
}
