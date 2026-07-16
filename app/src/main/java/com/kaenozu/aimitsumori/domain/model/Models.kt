package com.kaenozu.aimitsumori.domain.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
enum class InclusionStatus(val code: String, val labelJa: String) {
    @SerialName("included")
    INCLUDED("included", "見積内"),

    @SerialName("excluded")
    EXCLUDED("excluded", "対象外"),

    @SerialName("separate")
    SEPARATE("separate", "別途"),

    @SerialName("optional")
    OPTIONAL("optional", "オプション"),

    @SerialName("unknown")
    UNKNOWN("unknown", "不明"),

    @SerialName("not_applicable")
    NOT_APPLICABLE("not_applicable", "該当なし"),
    ;

    companion object {
        fun fromCode(code: String): InclusionStatus =
            entries.firstOrNull { it.code == code } ?: UNKNOWN
    }
}

@Serializable
enum class ProjectStatus(val code: String, val labelJa: String) {
    @SerialName("draft")
    DRAFT("draft", "下書き"),

    @SerialName("collecting_quotes")
    COLLECTING_QUOTES("collecting_quotes", "見積収集中"),

    @SerialName("needs_review")
    NEEDS_REVIEW("needs_review", "要確認"),

    @SerialName("comparing")
    COMPARING("comparing", "比較中"),

    @SerialName("clarifying")
    CLARIFYING("clarifying", "確認中"),

    @SerialName("decided")
    DECIDED("decided", "決定済み"),

    @SerialName("archived")
    ARCHIVED("archived", "アーカイブ"),
    ;

    companion object {
        fun fromCode(code: String): ProjectStatus =
            entries.firstOrNull { it.code == code } ?: DRAFT
    }
}

@Serializable
enum class QuestionStatus(val code: String) {
    @SerialName("open")
    OPEN("open"),

    @SerialName("resolved")
    RESOLVED("resolved"),
    ;

    companion object {
        fun fromCode(code: String): QuestionStatus =
            entries.firstOrNull { it.code == code } ?: OPEN
    }
}

@Serializable
data class CategoryDefinition(
    val id: String,
    val displayOrder: Int,
    val nameJa: String,
    val quantityExpected: Boolean,
    val specificationExpected: Boolean,
)

@Serializable
data class QuoteLineItem(
    val id: String,
    val categoryId: String,
    val rawLabel: String,
    val amountYen: Long? = null,
    val inclusionStatus: InclusionStatus = InclusionStatus.UNKNOWN,
    val quantity: Double? = null,
    val unit: String? = null,
    val specification: String? = null,
    val note: String? = null,
    val sortOrder: Int = 0,
)

@Serializable
data class ContractorQuote(
    val id: String,
    val contractorName: String,
    val totalAmountYen: Long? = null,
    val note: String? = null,
    val createdAtEpochMillis: Long,
    val lineItems: List<QuoteLineItem> = emptyList(),
)

@Serializable
data class Project(
    val id: String,
    val name: String,
    val status: ProjectStatus,
    val createdAtEpochMillis: Long,
    val updatedAtEpochMillis: Long,
    val quotes: List<ContractorQuote> = emptyList(),
)

@Serializable
data class NormalizedLine(
    val category: CategoryDefinition,
    val inclusionStatus: InclusionStatus,
    val amountYen: Long?,
    val quantity: Double?,
    val unit: String?,
    val specification: String?,
    val sourceLineItemIds: List<String>,
    val uncertaintyReasons: List<String>,
)

@Serializable
data class NormalizedQuote(
    val quoteId: String,
    val contractorName: String,
    val totalAmountYen: Long?,
    val lines: List<NormalizedLine>,
)

@Serializable
data class ClarificationQuestion(
    val id: String,
    val projectId: String,
    val quoteId: String?,
    val contractorName: String?,
    val categoryId: String?,
    val templateKey: String,
    val questionText: String,
    val status: QuestionStatus = QuestionStatus.OPEN,
    val createdAtEpochMillis: Long,
)

@Serializable
data class QuoteSnapshot(
    val quoteId: String,
    val contractorName: String,
    val totalAmountYen: Long?,
    val includedCategoryCount: Int,
    val separateCategoryNames: List<String>,
    val optionalCategoryNames: List<String>,
    val unknownCategoryNames: List<String>,
    val uncertaintyCount: Int,
)

@Serializable
data class ComparisonCell(
    val quoteId: String,
    val contractorName: String,
    val inclusionStatus: InclusionStatus,
    val amountYen: Long?,
    val quantity: Double?,
    val unit: String?,
    val specification: String?,
    val uncertaintyReasons: List<String>,
)

@Serializable
data class CategoryComparison(
    val category: CategoryDefinition,
    val cells: List<ComparisonCell>,
)

@Serializable
data class ComparisonReport(
    val projectId: String,
    val projectName: String,
    val quoteSnapshots: List<QuoteSnapshot>,
    val categoryComparisons: List<CategoryComparison>,
    val summaryLines: List<String>,
    val clarificationQuestions: List<ClarificationQuestion>,
)
