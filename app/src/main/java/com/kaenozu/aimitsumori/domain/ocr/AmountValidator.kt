package com.kaenozu.aimitsumori.domain.ocr

data class AmountValidationResult(
    val inconsistencies: List<Inconsistency> = emptyList(),
)

data class Inconsistency(
    val type: InconsistencyType,
    val description: String,
)

enum class InconsistencyType {
    QTY_TIMES_PRICE_MISMATCH,
    SUBTOTAL_TOTAL_MISMATCH,
    TAX_RATE_SUSPICIOUS,
    DUPLICATE_AMOUNT,
    DIGIT_SEPARATOR_ERROR,
}

object AmountValidator {
    fun validate(
        subtotal: Long?,
        discount: Long?,
        tax: Long?,
        total: Long?,
        lineItems: List<LineItemAmount>,
    ): AmountValidationResult {
        val issues = mutableListOf<Inconsistency>()

        for (item in lineItems) {
            if (item.quantity != null && item.unitPrice != null && item.amount != null) {
                val expected = item.quantity * item.unitPrice
                if (kotlin.math.abs(expected - item.amount) > 10) {
                    issues += Inconsistency(
                        InconsistencyType.QTY_TIMES_PRICE_MISMATCH,
                        "${item.label}: 数量×単価=${expected}円, 金額=${item.amount}円",
                    )
                }
            }
        }

        if (subtotal != null && total != null) {
            val computedTotal = subtotal + (discount ?: 0L) + (tax ?: 0L)
            if (kotlin.math.abs(computedTotal - total) > 10) {
                issues += Inconsistency(
                    InconsistencyType.SUBTOTAL_TOTAL_MISMATCH,
                    "小計${subtotal}+値引き${discount ?: 0}+税${tax ?: 0}=${computedTotal}, 総額=${total}",
                )
            }
        }

        return AmountValidationResult(inconsistencies = issues)
    }
}

data class LineItemAmount(
    val label: String,
    val quantity: Long?,
    val unitPrice: Long?,
    val amount: Long?,
)
