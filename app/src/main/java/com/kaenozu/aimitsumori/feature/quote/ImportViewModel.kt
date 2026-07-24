package com.kaenozu.aimitsumori.feature.quote

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.kaenozu.aimitsumori.data.repository.QuoteRepository
import com.kaenozu.aimitsumori.domain.model.ContractorQuote
import com.kaenozu.aimitsumori.domain.model.InclusionStatus
import com.kaenozu.aimitsumori.domain.model.QuoteLineItem
import java.util.UUID
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class ImportedPage(
    val id: String,
    val uri: Uri,
    val pageNumber: Int,
    val isExcluded: Boolean = false,
)

data class ImportUiState(
    val projectId: String,
    val vendorName: String = "",
    val isRevision: Boolean = false,
    val pages: List<ImportedPage> = emptyList(),
    val step: ImportStep = ImportStep.SelectSource,
    val errorMessage: String? = null,
)

enum class ImportStep {
    SelectSource,
    AddPages,
    ConfirmPages,
    OcrProgress,
    ReviewResult,
    Complete,
}

class ImportViewModel(
    private val projectId: String,
    private val repository: QuoteRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(ImportUiState(projectId = projectId))
    val uiState: StateFlow<ImportUiState> = _uiState.asStateFlow()

    fun setVendorName(name: String) {
        _uiState.value = _uiState.value.copy(vendorName = name)
    }

    fun setRevision(isRevision: Boolean) {
        _uiState.value = _uiState.value.copy(isRevision = isRevision)
    }

    fun addPages(uris: List<Uri>) {
        val current = _uiState.value
        val newPages = uris.mapIndexed { index, uri ->
            ImportedPage(
                id = UUID.randomUUID().toString(),
                uri = uri,
                pageNumber = current.pages.size + index + 1,
            )
        }
        _uiState.value = current.copy(
            pages = current.pages + newPages,
            step = ImportStep.ConfirmPages,
        )
    }

    fun toggleExcludePage(pageId: String) {
        _uiState.value = _uiState.value.copy(
            pages = _uiState.value.pages.map { page ->
                if (page.id == pageId) page.copy(isExcluded = !page.isExcluded) else page
            },
        )
    }

    fun reorderPages(fromIndex: Int, toIndex: Int) {
        val mutable = _uiState.value.pages.toMutableList()
        val item = mutable.removeAt(fromIndex)
        mutable.add(toIndex, item)
        _uiState.value = _uiState.value.copy(
            pages = mutable.mapIndexed { i, page -> page.copy(pageNumber = i + 1) },
        )
    }

    fun startOcr() {
        _uiState.value = _uiState.value.copy(step = ImportStep.OcrProgress)
        viewModelScope.launch {
            val vendorName = _uiState.value.vendorName.ifBlank { "業者${System.currentTimeMillis() % 1000}" }
            val now = System.currentTimeMillis()

            val quote = ContractorQuote(
                id = UUID.randomUUID().toString(),
                contractorName = vendorName,
                totalAmountYen = null,
                note = null,
                createdAtEpochMillis = now,
                lineItems = emptyList(),
            )
            repository.addQuoteToProject(projectId, quote)

            _uiState.value = _uiState.value.copy(step = ImportStep.Complete)
        }
    }

    fun setStep(step: ImportStep) {
        _uiState.value = _uiState.value.copy(step = step)
    }

    class Factory(
        private val projectId: String,
        private val repository: QuoteRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            ImportViewModel(projectId, repository) as T
    }
}
