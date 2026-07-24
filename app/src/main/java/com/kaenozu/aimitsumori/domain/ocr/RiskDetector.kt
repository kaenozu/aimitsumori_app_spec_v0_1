package com.kaenozu.aimitsumori.domain.ocr

data class RiskDetection(
    val risks: List<RiskItem> = emptyList(),
)

data class RiskItem(
    val text: String,
    val category: RiskCategory,
    val description: String,
)

enum class RiskCategory {
    VAGUE_LUMP_SUM,
    ESTIMATE_ONLY,
    SUBJECT_TO_SITE,
    ADDITIONAL_COST,
    EXCLUDED_ITEM,
    REQUIRES_CONFIRMATION,
}

object RiskDetector {
    private val patterns = listOf(
        RiskPattern(RiskCategory.VAGUE_LUMP_SUM, listOf("一式", "一式")),
        RiskPattern(RiskCategory.ESTIMATE_ONLY, listOf("概算", "見込み", "参考価格", "参考")),
        RiskPattern(RiskCategory.SUBJECT_TO_SITE, listOf("現地確認", "現場合わせ", "状況による", "地中障害")),
        RiskPattern(RiskCategory.ADDITIONAL_COST, listOf("別途", "別途費用", "別途見積", "追加費用", "実費", "別料金")),
        RiskPattern(RiskCategory.EXCLUDED_ITEM, listOf("含まず", "対象外", "別途施工", "施主支給")),
        RiskPattern(RiskCategory.REQUIRES_CONFIRMATION, listOf("要相談", "要確認", "要打合", "追加工事", "必要に応じて", "数量変更")),
    )

    fun detect(text: String): RiskDetection {
        val found = patterns.flatMap { pattern ->
            pattern.keywords.filter { keyword ->
                text.contains(keyword)
            }.map { keyword ->
                RiskItem(
                    text = keyword,
                    category = pattern.category,
                    description = when (pattern.category) {
                        RiskCategory.VAGUE_LUMP_SUM -> "一式の内訳が不明です。業者へ確認を推奨"
                        RiskCategory.ESTIMATE_ONLY -> "概算金額です。確定額ではありません"
                        RiskCategory.SUBJECT_TO_SITE -> "現地状況により追加費用が発生する可能性があります"
                        RiskCategory.ADDITIONAL_COST -> "別途費用の条件と金額を確認してください"
                        RiskCategory.EXCLUDED_ITEM -> "対象外の項目です。別途見積を依頼してください"
                        RiskCategory.REQUIRES_CONFIRMATION -> "内容が曖昧です。業者へ確認してください"
                    },
                )
            }
        }
        return RiskDetection(risks = found)
    }

    private data class RiskPattern(
        val category: RiskCategory,
        val keywords: List<String>,
    )
}
