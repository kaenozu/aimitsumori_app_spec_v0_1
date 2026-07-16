package com.kaenozu.aimitsumori.domain.comparison

import com.kaenozu.aimitsumori.data.local.CategoryMaster
import com.kaenozu.aimitsumori.domain.model.CategoryComparison
import com.kaenozu.aimitsumori.domain.model.ClarificationQuestion
import com.kaenozu.aimitsumori.domain.model.ComparisonCell
import com.kaenozu.aimitsumori.domain.model.ComparisonReport
import com.kaenozu.aimitsumori.domain.model.InclusionStatus
import com.kaenozu.aimitsumori.domain.model.NormalizedQuote
import com.kaenozu.aimitsumori.domain.model.Project
import com.kaenozu.aimitsumori.domain.model.QuoteSnapshot
import java.text.NumberFormat
import java.util.Locale

class ComparisonEngine {
    fun compare(
        project: Project,
        normalizedQuotes: List<NormalizedQuote>,
        questions: List<ClarificationQuestion>,
    ): ComparisonReport {
        require(normalizedQuotes.map { it.quoteId }.distinct().size == normalizedQuotes.size) {
            "quoteId must be unique"
        }

        val snapshots = normalizedQuotes.map { quote ->
            QuoteSnapshot(
                quoteId = quote.quoteId,
                contractorName = quote.contractorName,
                totalAmountYen = quote.totalAmountYen,
                includedCategoryCount = quote.lines.count {
                    it.inclusionStatus == InclusionStatus.INCLUDED
                },
                separateCategoryNames = quote.lines
                    .filter { it.inclusionStatus == InclusionStatus.SEPARATE }
                    .map { it.category.nameJa },
                optionalCategoryNames = quote.lines
                    .filter { it.inclusionStatus == InclusionStatus.OPTIONAL }
                    .map { it.category.nameJa },
                unknownCategoryNames = quote.lines
                    .filter { it.inclusionStatus == InclusionStatus.UNKNOWN }
                    .map { it.category.nameJa },
                uncertaintyCount = quote.lines.sumOf { it.uncertaintyReasons.size },
            )
        }

        val comparisons = CategoryMaster.categories.map { category ->
            CategoryComparison(
                category = category,
                cells = normalizedQuotes.map { quote ->
                    val line = requireNotNull(
                        quote.lines.firstOrNull { it.category.id == category.id },
                    )
                    ComparisonCell(
                        quoteId = quote.quoteId,
                        contractorName = quote.contractorName,
                        inclusionStatus = line.inclusionStatus,
                        amountYen = line.amountYen,
                        quantity = line.quantity,
                        unit = line.unit,
                        specification = line.specification,
                        uncertaintyReasons = line.uncertaintyReasons,
                    )
                },
            )
        }

        val summary = buildThreeLineSummary(snapshots, questions)
        check(summary.size == 3) { "Comparison summary must contain exactly three lines" }

        return ComparisonReport(
            projectId = project.id,
            projectName = project.name,
            quoteSnapshots = snapshots,
            categoryComparisons = comparisons,
            summaryLines = summary,
            clarificationQuestions = questions,
        )
    }

    private fun buildThreeLineSummary(
        snapshots: List<QuoteSnapshot>,
        questions: List<ClarificationQuestion>,
    ): List<String> {
        if (snapshots.isEmpty()) {
            return listOf(
                "見積総額: 見積は未登録です。",
                "範囲差: 比較対象がないため判定できません。",
                "要確認: まず見積書を登録してください。質問テンプレートは0件です。",
            )
        }

        val totalText = snapshots.joinToString(" / ") { snapshot ->
            "${snapshot.contractorName} ${formatYen(snapshot.totalAmountYen)}"
        }
        val knownTotals = snapshots.mapNotNull(QuoteSnapshot::totalAmountYen)
        val spreadText = if (knownTotals.size >= 2) {
            "、提示総額の幅は${formatYen(knownTotals.max() - knownTotals.min())}"
        } else {
            "、総額差は算出不能"
        }

        val scopeText = snapshots.joinToString(" / ") { snapshot ->
            "${snapshot.contractorName} 別途${snapshot.separateCategoryNames.size}件・任意${snapshot.optionalCategoryNames.size}件"
        }

        val unknownText = snapshots.joinToString(" / ") { snapshot ->
            "${snapshot.contractorName} 不明カテゴリ${snapshot.unknownCategoryNames.size}件・不確実点${snapshot.uncertaintyCount}件"
        }

        return listOf(
            "見積総額: $totalText$spreadText。",
            "範囲差: $scopeText。別途・任意項目は総額だけでは比較できません。",
            "要確認: $unknownText。質問テンプレート${questions.size}件を生成しました。",
        )
    }

    private fun formatYen(value: Long?): String =
        value?.let { "${NumberFormat.getNumberInstance(Locale.JAPAN).format(it)}円" } ?: "不明"
}
