package com.kaenozu.aimitsumori.data.local

data class ChecklistCategory(
    val id: String,
    val nameJa: String,
    val items: List<ChecklistItem>,
)

data class ChecklistItem(
    val id: String,
    val nameJa: String,
    val expectsQuantity: Boolean = false,
    val expectsSpecification: Boolean = false,
)

object RequirementMaster {
    val categories: List<ChecklistCategory> = listOf(
        ChecklistCategory("parking", "駐車場", listOf(
            ChecklistItem("parking_cars", "台数", expectsQuantity = true),
            ChecklistItem("parking_finish", "仕上げ", expectsSpecification = true),
            ChecklistItem("parking_area", "面積", expectsQuantity = true),
            ChecklistItem("parking_concrete_thickness", "コンクリート厚", expectsSpecification = true),
            ChecklistItem("parking_rebar", "配筋", expectsSpecification = true),
            ChecklistItem("parking_joint", "目地", expectsSpecification = true),
            ChecklistItem("parking_slope", "勾配", expectsSpecification = true),
            ChecklistItem("parking_drainage", "排水", expectsSpecification = true),
            ChecklistItem("parking_existing_removal", "既存構造物撤去"),
        )),
        ChecklistCategory("fence", "フェンス", listOf(
            ChecklistItem("fence_range", "設置範囲", expectsSpecification = true),
            ChecklistItem("fence_height", "高さ", expectsQuantity = true),
            ChecklistItem("fence_privacy", "目隠し率", expectsSpecification = true),
            ChecklistItem("fence_product", "商品指定", expectsSpecification = true),
            ChecklistItem("fence_foundation", "基礎ブロック", expectsSpecification = true),
        )),
        ChecklistCategory("carport", "カーポート", listOf(
            ChecklistItem("carport_cars", "台数", expectsQuantity = true),
            ChecklistItem("carport_model", "メーカー・型番", expectsSpecification = true),
            ChecklistItem("carport_snow", "耐雪", expectsSpecification = true),
            ChecklistItem("carport_wind", "耐風", expectsSpecification = true),
            ChecklistItem("carport_lighting", "照明・電源"),
            ChecklistItem("carport_interference", "土間工事との取り合い"),
        )),
        ChecklistCategory("common", "共通", listOf(
            ChecklistItem("common_demolition", "解体撤去"),
            ChecklistItem("common_soil_disposal", "残土処分"),
            ChecklistItem("common_protection", "養生"),
            ChecklistItem("common_machinery", "重機回送"),
            ChecklistItem("common_traffic", "交通誘導"),
            ChecklistItem("common_application", "申請"),
            ChecklistItem("common_overhead", "諸経費"),
            ChecklistItem("common_tax", "消費税"),
            ChecklistItem("common_warranty", "保証", expectsSpecification = true),
            ChecklistItem("common_additional_terms", "追加料金条件", expectsSpecification = true),
        )),
    )

    fun findByItemId(itemId: String): ChecklistItem? =
        categories.flatMap { it.items }.firstOrNull { it.id == itemId }
}
