package com.kaenozu.aimitsumori.feature.quote

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ImportScreen(
    viewModel: ImportViewModel,
    onBack: () -> Unit,
    onComplete: () -> Unit,
) {
    val pdfLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetContent(),
    ) { uri: Uri? ->
        if (uri != null) viewModel.addPages(listOf(uri))
    }
    val imageLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.GetMultipleContents(),
    ) { uris: List<Uri> ->
        if (uris.isNotEmpty()) viewModel.addPages(uris)
    }
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("見積書追加") },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.Default.ArrowBack, contentDescription = "戻る")
                    }
                },
            )
        },
    ) { padding ->
        when (uiState.step) {
            ImportStep.SelectSource -> SelectSourceStep(
                onSelectPdf = { pdfLauncher.launch("application/pdf") },
                onSelectImage = { imageLauncher.launch("image/*") },
                modifier = Modifier.padding(padding),
            )

            ImportStep.AddPages -> AddPagesStep(
                vendorName = uiState.vendorName,
                onVendorNameChange = viewModel::setVendorName,
                isRevision = uiState.isRevision,
                onRevisionChange = viewModel::setRevision,
                onContinue = { viewModel.setStep(ImportStep.ConfirmPages) },
                onAddMoreFiles = { imageLauncher.launch("image/*") },
                modifier = Modifier.padding(padding),
            )

            ImportStep.ConfirmPages -> ConfirmPagesStep(
                pages = uiState.pages,
                vendorName = uiState.vendorName,
                onVendorNameChange = viewModel::setVendorName,
                onToggleExclude = viewModel::toggleExcludePage,
                onStartOcr = viewModel::startOcr,
                modifier = Modifier.padding(padding),
            )

            ImportStep.OcrProgress -> OcrProgressStep(
                modifier = Modifier.padding(padding),
            )

            ImportStep.Complete -> ImportCompleteStep(
                onViewComparison = onComplete,
                onAddMore = { viewModel.setStep(ImportStep.SelectSource) },
                modifier = Modifier.padding(padding),
            )

            ImportStep.ReviewResult -> ReviewResultStep(
                onAccept = onComplete,
                modifier = Modifier.padding(padding),
            )
        }
    }
}

@Composable
private fun SelectSourceStep(
    onSelectPdf: () -> Unit,
    onSelectImage: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(48.dp))
        Text("見積書の読み取り元を選択", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(16.dp))
        Button(onClick = onSelectPdf, modifier = Modifier.fillMaxWidth()) {
            Text("PDFファイルを選択")
        }
        OutlinedButton(onClick = onSelectImage, modifier = Modifier.fillMaxWidth()) {
            Text("画像を選択（ギャラリー）")
        }
        OutlinedButton(onClick = { }, modifier = Modifier.fillMaxWidth()) {
            Text("カメラで撮影")
        }
    }
}

@Composable
private fun AddPagesStep(
    vendorName: String,
    onVendorNameChange: (String) -> Unit,
    isRevision: Boolean,
    onRevisionChange: (Boolean) -> Unit,
    onContinue: () -> Unit,
    onAddMoreFiles: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp),
    ) {
        OutlinedTextField(
            value = vendorName,
            onValueChange = onVendorNameChange,
            label = { Text("業者名") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("改訂版として追加")
            Switch(checked = isRevision, onCheckedChange = onRevisionChange)
        }
        Button(onClick = onContinue, modifier = Modifier.fillMaxWidth()) {
            Text("続けてページを確認")
        }
        OutlinedButton(onClick = onAddMoreFiles, modifier = Modifier.fillMaxWidth()) {
            Text("ファイルを追加")
        }
    }
}

@Composable
private fun ConfirmPagesStep(
    pages: List<ImportedPage>,
    vendorName: String,
    onVendorNameChange: (String) -> Unit,
    onToggleExclude: (String) -> Unit,
    onStartOcr: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxSize().padding(16.dp)) {
        OutlinedTextField(
            value = vendorName,
            onValueChange = onVendorNameChange,
            label = { Text("業者名") },
            singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        Text("ページ一覧（${pages.size}ページ）", style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.height(8.dp))
        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            items(pages, key = ImportedPage::id) { page ->
                Card(
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Row(
                        modifier = Modifier.padding(8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Text(
                            "${page.pageNumber}",
                            modifier = Modifier.size(32.dp),
                            style = MaterialTheme.typography.bodyLarge,
                        )
                        Text(
                            page.uri.lastPathSegment ?: "ページ${page.pageNumber}",
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.weight(1f),
                        )
                        Checkbox(
                            checked = page.isExcluded,
                            onCheckedChange = { onToggleExclude(page.id) },
                        )
                    }
                }
            }
        }
        Spacer(Modifier.height(12.dp))
        Button(
            onClick = onStartOcr,
            modifier = Modifier.fillMaxWidth(),
            enabled = vendorName.isNotBlank(),
        ) {
            Text("読み取りを開始")
        }
    }
}

@Composable
private fun OcrProgressStep(modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        CircularProgressIndicator()
        Spacer(Modifier.height(16.dp))
        Text("見積書を読み取り中…")
        Spacer(Modifier.height(8.dp))
        LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
        Spacer(Modifier.height(8.dp))
        Text("ページ準備 → OCR → 金額抽出 → 正規化", style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun ReviewResultStep(
    onAccept: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("読み取り結果", style = MaterialTheme.typography.titleLarge)
        Text("確認が必要な項目があります（将来実装）")
        Spacer(Modifier.weight(1f))
        Button(onClick = onAccept, modifier = Modifier.fillMaxWidth()) {
            Text("確定して比較へ")
        }
    }
}

@Composable
private fun ImportCompleteStep(
    onViewComparison: () -> Unit,
    onAddMore: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier.fillMaxSize().padding(16.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("見積書の追加が完了しました", style = MaterialTheme.typography.titleLarge)
        Spacer(Modifier.height(24.dp))
        Button(onClick = onViewComparison, modifier = Modifier.fillMaxWidth()) {
            Text("比較画面へ")
        }
        OutlinedButton(onClick = onAddMore, modifier = Modifier.fillMaxWidth()) {
            Icon(Icons.Default.Add, contentDescription = null)
            Text("別の業者を追加")
        }
    }
}
