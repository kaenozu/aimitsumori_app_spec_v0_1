package com.kaenozu.aimitsumori.feature.review

import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.kaenozu.aimitsumori.data.repository.QuoteRepository
import com.kaenozu.aimitsumori.domain.ocr.AmountValidator
import com.kaenozu.aimitsumori.domain.ocr.LineItemAmount
import com.kaenozu.aimitsumori.domain.ocr.RiskDetector
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

data class ReviewItem(
    val id: String,
    val type: ReviewType,
    val question: String,
    val sourceText: String,
    val vendorName: String,
    val status: ReviewStatus = ReviewStatus.PENDING,
    val correctedValue: String = "",
)

enum class ReviewType {
    TOTAL_AMOUNT, INCLUSION_STATUS, LUMP_SUM, PRODUCT_CODE, QTY_PRICE_MISMATCH, SUBTOTAL_MISMATCH, MISSING_INFO
}

enum class ReviewStatus {
    PENDING, CORRECT, FIXED, UNKNOWN, ASK_VENDOR, NOT_APPLICABLE
}

data class ReviewUiState(
    val items: List<ReviewItem> = emptyList(),
    val currentIndex: Int = 0,
    val isComplete: Boolean = false,
)

class ReviewViewModel(
    private val projectId: String,
    private val repository: QuoteRepository,
) : ViewModel() {
    private val _uiState = MutableStateFlow(ReviewUiState())
    val uiState: StateFlow<ReviewUiState> = _uiState.asStateFlow()

    init {
        viewModelScope.launch {
            val project = repository.observeProject(projectId).first()
            if (project == null) return@launch

            val items = mutableListOf<ReviewItem>()
            project.quotes.forEach { quote ->
                quote.lineItems.forEach { line ->
                    RiskDetector.detect(line.rawLabel).risks.forEach { risk ->
                        items += ReviewItem(
                            id = "${quote.id}|${line.id}|${risk.category}",
                            type = ReviewType.INCLUSION_STATUS,
                            question = "${quote.contractorName}: 「${line.rawLabel}」${risk.description}",
                            sourceText = line.rawLabel,
                            vendorName = quote.contractorName,
                        )
                    }
                }

                val validation = AmountValidator.validate(
                    subtotal = null, discount = null, tax = null,
                    total = quote.totalAmountYen,
                    lineItems = quote.lineItems.map { LineItemAmount(it.rawLabel, null, null, it.amountYen) },
                )
                validation.inconsistencies.forEach { inc ->
                    items += ReviewItem(
                        id = "${quote.id}|${inc.type}",
                        type = ReviewType.QTY_PRICE_MISMATCH,
                        question = "${quote.contractorName}: ${inc.description}",
                        sourceText = inc.description,
                        vendorName = quote.contractorName,
                    )
                }

                if (quote.totalAmountYen == null) {
                    items += ReviewItem(
                        id = "${quote.id}|missing-total",
                        type = ReviewType.TOTAL_AMOUNT,
                        question = "${quote.contractorName}: 税込総額が不明です。正しい金額を入力してください。",
                        sourceText = "",
                        vendorName = quote.contractorName,
                    )
                }
            }

            _uiState.value = ReviewUiState(items = items)
        }
    }

    fun setStatus(itemId: String, status: ReviewStatus) {
        updateItem(itemId) { it.copy(status = status) }
    }

    fun setCorrectedValue(itemId: String, value: String) {
        updateItem(itemId) { it.copy(correctedValue = value) }
    }

    fun nextItem() {
        val current = _uiState.value
        if (current.currentIndex < current.items.size - 1) {
            _uiState.value = current.copy(currentIndex = current.currentIndex + 1)
        } else {
            _uiState.value = current.copy(isComplete = true)
        }
    }

    private fun updateItem(itemId: String, transform: (ReviewItem) -> ReviewItem) {
        val current = _uiState.value
        _uiState.value = current.copy(
            items = current.items.map { if (it.id == itemId) transform(it) else it },
        )
    }

    class Factory(
        private val projectId: String,
        private val repository: QuoteRepository,
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            ReviewViewModel(projectId, repository) as T
    }
}
