package com.kaenozu.aimitsumori.domain.ocr

enum class PageType {
    COVER_TOTAL,
    ITEM_DETAIL,
    PRODUCT_SPEC,
    NOTES,
    PAYMENT_TERMS,
    WARRANTY,
    DRAWING,
    OTHER,
}

object PageClassifier {
    private val patterns = listOf(
        PagePattern(PageType.COVER_TOTAL, listOf("見積書", "見積もり書", "お見積", "見積番号", "見積日", "見積有効期限", "御見積")),
        PagePattern(PageType.ITEM_DETAIL, listOf("工事項目", "明細", "工事内容", "摘要", "数量", "単価", "金額", "施工項目")),
        PagePattern(PageType.PRODUCT_SPEC, listOf("製品仕様", "型番", "商品名", "品番", "メーカー")),
        PagePattern(PageType.NOTES, listOf("注意事項", "特記事項", "備考", "施工条件")),
        PagePattern(PageType.PAYMENT_TERMS, listOf("支払条件", "支払方法", "お支払い", "着手金", "中間金", "完了金")),
        PagePattern(PageType.WARRANTY, listOf("保証", "アフター", "定期点検")),
        PagePattern(PageType.DRAWING, listOf("図面", "平面図", "立面図", "配置図", "断面図")),
    )

    fun classify(text: String): PageType {
        for (pattern in patterns) {
            if (pattern.keywords.any { text.contains(it) }) {
                return pattern.type
            }
        }
        return PageType.OTHER
    }

    private data class PagePattern(
        val type: PageType,
        val keywords: List<String>,
    )
}
