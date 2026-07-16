package com.kaenozu.aimitsumori.domain.normalization

import com.kaenozu.aimitsumori.data.local.CategoryMaster
import com.kaenozu.aimitsumori.domain.model.InclusionStatus
import com.kaenozu.aimitsumori.domain.model.NormalizedLine
import com.kaenozu.aimitsumori.domain.model.NormalizedQuote
import com.kaenozu.aimitsumori.domain.model.Project
import com.kaenozu.aimitsumori.domain.model.QuoteLineItem

class Normalizer {
    fun normalize(project: Project): List<NormalizedQuote> =
        project.quotes.map { quote ->
            val itemsByCategory = quote.lineItems.groupBy(QuoteLineItem::categoryId)
            NormalizedQuote(
                quoteId = quote.id,
                contractorName = quote.contractorName,
                totalAmountYen = quote.totalAmountYen,
                lines = CategoryMaster.categories.map { category ->
                    normalizeCategory(
                        categoryId = category.id,
                        items = itemsByCategory[category.id].orEmpty(),
                    )
                },
            )
        }

    private fun normalizeCategory(
        categoryId: String,
        items: List<QuoteLineItem>,
    ): NormalizedLine {
        val category = CategoryMaster.require(categoryId)
        if (items.isEmpty()) {
            return NormalizedLine(
                category = category,
                inclusionStatus = InclusionStatus.UNKNOWN,
                amountYen = null,
                quantity = null,
                unit = null,
                specification = null,
                sourceLineItemIds = emptyList(),
                uncertaintyReasons = listOf("見積明細に記載がありません"),
            )
        }

        val reasons = mutableListOf<String>()
        val distinctStatuses = items.map(QuoteLineItem::inclusionStatus).distinct()
        val status = if (distinctStatuses.size == 1) {
            distinctStatuses.single()
        } else {
            reasons += "同じカテゴリ内で含有状態が一致していません"
            InclusionStatus.UNKNOWN
        }

        val amount = when {
            items.all { it.amountYen == null } -> null
            items.any { it.amountYen == null } -> {
                reasons += "金額未記載の明細を含みます"
                items.mapNotNull(QuoteLineItem::amountYen).sum()
            }
            else -> items.sumOf { requireNotNull(it.amountYen) }
        }

        val quantityValues = items.mapNotNull(QuoteLineItem::quantity).distinct()
        val unitValues = items.mapNotNull { it.unit?.trim()?.takeIf(String::isNotEmpty) }.distinct()
        val quantity = quantityValues.singleOrNull()
        val unit = unitValues.singleOrNull()
        if (category.quantityExpected && (quantity == null || unit == null)) {
            reasons += "数量または単位が不明です"
        }
        if (quantityValues.size > 1 || unitValues.size > 1) {
            reasons += "複数明細の数量・単位を単一値へ統合できません"
        }

        val specificationValues = items
            .mapNotNull { it.specification?.trim()?.takeIf(String::isNotEmpty) }
            .distinct()
        val specification = specificationValues.singleOrNull()
        if (category.specificationExpected && specification == null) {
            reasons += "仕様・型番が不明です"
        }
        if (specificationValues.size > 1) {
            reasons += "複数の仕様・型番が混在しています"
        }
        if (status == InclusionStatus.UNKNOWN) {
            reasons += "見積に含むかどうか不明です"
        }

        return NormalizedLine(
            category = category,
            inclusionStatus = status,
            amountYen = amount,
            quantity = quantity,
            unit = unit,
            specification = specification,
            sourceLineItemIds = items.map(QuoteLineItem::id),
            uncertaintyReasons = reasons.distinct(),
        )
    }
}
