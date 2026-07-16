package com.kaenozu.aimitsumori.domain.clarification

import com.kaenozu.aimitsumori.domain.model.ClarificationQuestion
import com.kaenozu.aimitsumori.domain.model.InclusionStatus
import com.kaenozu.aimitsumori.domain.model.NormalizedLine
import com.kaenozu.aimitsumori.domain.model.NormalizedQuote
import com.kaenozu.aimitsumori.domain.model.Project
import java.util.UUID

class QuestionGenerator {
    fun generate(
        project: Project,
        normalizedQuotes: List<NormalizedQuote>,
        nowEpochMillis: Long = System.currentTimeMillis(),
    ): List<ClarificationQuestion> = buildList {
        normalizedQuotes.forEach { quote ->
            quote.lines.forEach { line ->
                addAll(
                    questionsForLine(
                        projectId = project.id,
                        quote = quote,
                        line = line,
                        nowEpochMillis = nowEpochMillis,
                    ),
                )
            }
        }
    }

    private fun questionsForLine(
        projectId: String,
        quote: NormalizedQuote,
        line: NormalizedLine,
        nowEpochMillis: Long,
    ): List<ClarificationQuestion> {
        val categoryName = line.category.nameJa
        val contractorName = quote.contractorName
        val questions = mutableListOf<Pair<String, String>>()

        when (line.inclusionStatus) {
            InclusionStatus.UNKNOWN -> questions +=
                "UNKNOWN_INCLUSION" to
                    "${contractorName}様：${categoryName}は見積金額に含まれていますか。含む・別途・対象外のいずれかをご回答ください。"

            InclusionStatus.SEPARATE -> questions +=
                "SEPARATE_SCOPE" to
                    "${contractorName}様：別途扱いの${categoryName}は工事に必須ですか。必要な場合の追加金額と発生条件をご提示ください。"

            InclusionStatus.OPTIONAL -> questions +=
                "OPTIONAL_SCOPE" to
                    "${contractorName}様：オプション扱いの${categoryName}について、採用時の追加金額と標準仕様との差をご提示ください。"

            else -> Unit
        }

        val requiresDetail = line.inclusionStatus !in setOf(
            InclusionStatus.EXCLUDED,
            InclusionStatus.NOT_APPLICABLE,
        )

        if (line.amountYen == null && requiresDetail) {
            questions +=
                "MISSING_AMOUNT" to
                    "${contractorName}様：${categoryName}の金額が不明です。税込・税抜の別も含めて金額をご提示ください。"
        }

        if (requiresDetail && line.category.quantityExpected &&
            (line.quantity == null || line.unit == null)
        ) {
            questions +=
                "MISSING_QUANTITY" to
                    "${contractorName}様：${categoryName}の数量と単位、および算定根拠をご提示ください。"
        }

        if (requiresDetail && line.category.specificationExpected &&
            line.specification == null
        ) {
            questions +=
                "MISSING_SPECIFICATION" to
                    "${contractorName}様：${categoryName}の製品名・型番・寸法・施工仕様をご提示ください。"
        }

        return questions.distinctBy { it.first }.map { (templateKey, text) ->
            ClarificationQuestion(
                id = UUID.nameUUIDFromBytes(
                    "${projectId}|${quote.quoteId}|${line.category.id}|$templateKey".toByteArray(),
                ).toString(),
                projectId = projectId,
                quoteId = quote.quoteId,
                contractorName = contractorName,
                categoryId = line.category.id,
                templateKey = templateKey,
                questionText = text,
                createdAtEpochMillis = nowEpochMillis,
            )
        }
    }
}
