package com.kaenozu.aimitsumori.data.local

import com.kaenozu.aimitsumori.domain.model.Project
import kotlinx.serialization.json.Json

object SampleData {
    private val json = Json {
        ignoreUnknownKeys = false
    }

    fun project(): Project = json.decodeFromString(SAMPLE_PROJECT_JSON)

    const val SAMPLE_PROJECT_JSON: String = """
{
  "id": "sample-exterior-001",
  "name": "新築外構 3社相見積もり",
  "status": "needs_review",
  "createdAtEpochMillis": 1784160000000,
  "updatedAtEpochMillis": 1784160003000,
  "quotes": [
    {
      "id": "quote-a",
      "contractorName": "A社",
      "totalAmountYen": 2530000,
      "note": "提示総額は最も低いが、残土処分と排水が別途。",
      "createdAtEpochMillis": 1784160001000,
      "lineItems": [
        {
          "id": "quote-a-01",
          "categoryId": "concrete",
          "rawLabel": "土間コンクリート",
          "amountYen": 800000,
          "inclusionStatus": "included",
          "quantity": 120.0,
          "unit": "㎡",
          "specification": "刷毛引き t=100mm・ワイヤーメッシュ",
          "note": null,
          "sortOrder": 1
        },
        {
          "id": "quote-a-02",
          "categoryId": "gravel_paving",
          "rawLabel": "砂利・舗装",
          "amountYen": 120000,
          "inclusionStatus": "included",
          "quantity": 80.0,
          "unit": "㎡",
          "specification": "砕石40mm",
          "note": null,
          "sortOrder": 2
        },
        {
          "id": "quote-a-03",
          "categoryId": "carport",
          "rawLabel": "カーポート",
          "amountYen": 450000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": "2台用・型番未記載",
          "note": null,
          "sortOrder": 3
        },
        {
          "id": "quote-a-04",
          "categoryId": "fence",
          "rawLabel": "フェンス",
          "amountYen": 280000,
          "inclusionStatus": "included",
          "quantity": 22.0,
          "unit": "m",
          "specification": "アルミ形材 H=1000",
          "note": null,
          "sortOrder": 4
        },
        {
          "id": "quote-a-05",
          "categoryId": "gate",
          "rawLabel": "門柱・門扉",
          "amountYen": 180000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": "機能門柱",
          "note": null,
          "sortOrder": 5
        },
        {
          "id": "quote-a-06",
          "categoryId": "approach",
          "rawLabel": "アプローチ",
          "amountYen": 160000,
          "inclusionStatus": "included",
          "quantity": 18.0,
          "unit": "㎡",
          "specification": "インターロッキング",
          "note": null,
          "sortOrder": 6
        },
        {
          "id": "quote-a-07",
          "categoryId": "earthwork",
          "rawLabel": "造成・掘削",
          "amountYen": 90000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 7
        },
        {
          "id": "quote-a-08",
          "categoryId": "soil_disposal",
          "rawLabel": "残土処分",
          "amountYen": 150000,
          "inclusionStatus": "separate",
          "quantity": 12.0,
          "unit": "㎥",
          "specification": null,
          "note": null,
          "sortOrder": 8
        },
        {
          "id": "quote-a-09",
          "categoryId": "drainage",
          "rawLabel": "排水",
          "amountYen": 120000,
          "inclusionStatus": "separate",
          "quantity": 1.0,
          "unit": "式",
          "specification": "雨水桝接続",
          "note": null,
          "sortOrder": 9
        },
        {
          "id": "quote-a-10",
          "categoryId": "lighting",
          "rawLabel": "照明・電気",
          "amountYen": 80000,
          "inclusionStatus": "optional",
          "quantity": 2.0,
          "unit": "灯",
          "specification": "ローポールライト",
          "note": null,
          "sortOrder": 10
        },
        {
          "id": "quote-a-11",
          "categoryId": "planting",
          "rawLabel": "植栽",
          "amountYen": null,
          "inclusionStatus": "excluded",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 11
        },
        {
          "id": "quote-a-12",
          "categoryId": "demolition",
          "rawLabel": "解体・撤去",
          "amountYen": 60000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 12
        },
        {
          "id": "quote-a-13",
          "categoryId": "protection",
          "rawLabel": "養生",
          "amountYen": 40000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 13
        },
        {
          "id": "quote-a-14",
          "categoryId": "machinery_transport",
          "rawLabel": "重機回送",
          "amountYen": 50000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 14
        },
        {
          "id": "quote-a-15",
          "categoryId": "overhead",
          "rawLabel": "諸経費",
          "amountYen": 120000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 15
        },
        {
          "id": "quote-a-16",
          "categoryId": "application",
          "rawLabel": "申請",
          "amountYen": 30000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 16
        },
        {
          "id": "quote-a-17",
          "categoryId": "discount",
          "rawLabel": "値引き",
          "amountYen": -100000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 17
        },
        {
          "id": "quote-a-18",
          "categoryId": "tax",
          "rawLabel": "消費税",
          "amountYen": 250000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 18
        }
      ]
    },
    {
      "id": "quote-b",
      "contractorName": "B社",
      "totalAmountYen": 3450000,
      "note": "提示総額は高めだが、必須項目の範囲と仕様が比較的明確。",
      "createdAtEpochMillis": 1784160002000,
      "lineItems": [
        {
          "id": "quote-b-01",
          "categoryId": "concrete",
          "rawLabel": "土間コンクリート",
          "amountYen": 900000,
          "inclusionStatus": "included",
          "quantity": 120.0,
          "unit": "㎡",
          "specification": "刷毛引き t=120mm・D10メッシュ",
          "note": null,
          "sortOrder": 1
        },
        {
          "id": "quote-b-02",
          "categoryId": "gravel_paving",
          "rawLabel": "砂利・舗装",
          "amountYen": 150000,
          "inclusionStatus": "included",
          "quantity": 80.0,
          "unit": "㎡",
          "specification": "再生砕石50mm",
          "note": null,
          "sortOrder": 2
        },
        {
          "id": "quote-b-03",
          "categoryId": "carport",
          "rawLabel": "カーポート",
          "amountYen": 560000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": "LIXIL カーポートSC 2台用",
          "note": null,
          "sortOrder": 3
        },
        {
          "id": "quote-b-04",
          "categoryId": "fence",
          "rawLabel": "フェンス",
          "amountYen": 320000,
          "inclusionStatus": "included",
          "quantity": 22.0,
          "unit": "m",
          "specification": "LIXIL フェンスAB H=1200",
          "note": null,
          "sortOrder": 4
        },
        {
          "id": "quote-b-05",
          "categoryId": "gate",
          "rawLabel": "門柱・門扉",
          "amountYen": 210000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": "宅配ボックス付機能門柱",
          "note": null,
          "sortOrder": 5
        },
        {
          "id": "quote-b-06",
          "categoryId": "approach",
          "rawLabel": "アプローチ",
          "amountYen": 190000,
          "inclusionStatus": "included",
          "quantity": 18.0,
          "unit": "㎡",
          "specification": "天然石調平板",
          "note": null,
          "sortOrder": 6
        },
        {
          "id": "quote-b-07",
          "categoryId": "earthwork",
          "rawLabel": "造成・掘削",
          "amountYen": 120000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 7
        },
        {
          "id": "quote-b-08",
          "categoryId": "soil_disposal",
          "rawLabel": "残土処分",
          "amountYen": 160000,
          "inclusionStatus": "included",
          "quantity": 12.0,
          "unit": "㎥",
          "specification": null,
          "note": null,
          "sortOrder": 8
        },
        {
          "id": "quote-b-09",
          "categoryId": "drainage",
          "rawLabel": "排水",
          "amountYen": 150000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": "雨水・汚水経路調整含む",
          "note": null,
          "sortOrder": 9
        },
        {
          "id": "quote-b-10",
          "categoryId": "lighting",
          "rawLabel": "照明・電気",
          "amountYen": 110000,
          "inclusionStatus": "included",
          "quantity": 3.0,
          "unit": "灯",
          "specification": "Panasonic LED・配線含む",
          "note": null,
          "sortOrder": 10
        },
        {
          "id": "quote-b-11",
          "categoryId": "planting",
          "rawLabel": "植栽",
          "amountYen": 60000,
          "inclusionStatus": "optional",
          "quantity": 3.0,
          "unit": "本",
          "specification": "常緑樹 H=2.0m",
          "note": null,
          "sortOrder": 11
        },
        {
          "id": "quote-b-12",
          "categoryId": "demolition",
          "rawLabel": "解体・撤去",
          "amountYen": 70000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 12
        },
        {
          "id": "quote-b-13",
          "categoryId": "protection",
          "rawLabel": "養生",
          "amountYen": 50000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 13
        },
        {
          "id": "quote-b-14",
          "categoryId": "machinery_transport",
          "rawLabel": "重機回送",
          "amountYen": 60000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 14
        },
        {
          "id": "quote-b-15",
          "categoryId": "overhead",
          "rawLabel": "諸経費",
          "amountYen": 160000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 15
        },
        {
          "id": "quote-b-16",
          "categoryId": "application",
          "rawLabel": "申請",
          "amountYen": 40000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 16
        },
        {
          "id": "quote-b-17",
          "categoryId": "discount",
          "rawLabel": "値引き",
          "amountYen": -80000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 17
        },
        {
          "id": "quote-b-18",
          "categoryId": "tax",
          "rawLabel": "消費税",
          "amountYen": 280000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 18
        }
      ]
    },
    {
      "id": "quote-c",
      "contractorName": "C社",
      "totalAmountYen": 2785000,
      "note": "数量・単位・製品型番の未記載が多い。",
      "createdAtEpochMillis": 1784160003000,
      "lineItems": [
        {
          "id": "quote-c-01",
          "categoryId": "concrete",
          "rawLabel": "土間コンクリート",
          "amountYen": 850000,
          "inclusionStatus": "included",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 1
        },
        {
          "id": "quote-c-02",
          "categoryId": "gravel_paving",
          "rawLabel": "砂利・舗装",
          "amountYen": 130000,
          "inclusionStatus": "included",
          "quantity": null,
          "unit": null,
          "specification": "砕石",
          "note": null,
          "sortOrder": 2
        },
        {
          "id": "quote-c-03",
          "categoryId": "carport",
          "rawLabel": "カーポート",
          "amountYen": 500000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 3
        },
        {
          "id": "quote-c-04",
          "categoryId": "fence",
          "rawLabel": "フェンス",
          "amountYen": 300000,
          "inclusionStatus": "included",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 4
        },
        {
          "id": "quote-c-05",
          "categoryId": "gate",
          "rawLabel": "門柱・門扉",
          "amountYen": 190000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 5
        },
        {
          "id": "quote-c-06",
          "categoryId": "approach",
          "rawLabel": "アプローチ",
          "amountYen": 170000,
          "inclusionStatus": "included",
          "quantity": null,
          "unit": null,
          "specification": "平板舗装",
          "note": null,
          "sortOrder": 6
        },
        {
          "id": "quote-c-07",
          "categoryId": "earthwork",
          "rawLabel": "造成・掘削",
          "amountYen": 100000,
          "inclusionStatus": "included",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 7
        },
        {
          "id": "quote-c-08",
          "categoryId": "soil_disposal",
          "rawLabel": "残土処分",
          "amountYen": null,
          "inclusionStatus": "unknown",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 8
        },
        {
          "id": "quote-c-09",
          "categoryId": "drainage",
          "rawLabel": "排水",
          "amountYen": null,
          "inclusionStatus": "unknown",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 9
        },
        {
          "id": "quote-c-10",
          "categoryId": "lighting",
          "rawLabel": "照明・電気",
          "amountYen": 90000,
          "inclusionStatus": "optional",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 10
        },
        {
          "id": "quote-c-11",
          "categoryId": "planting",
          "rawLabel": "植栽",
          "amountYen": null,
          "inclusionStatus": "unknown",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 11
        },
        {
          "id": "quote-c-12",
          "categoryId": "demolition",
          "rawLabel": "解体・撤去",
          "amountYen": 65000,
          "inclusionStatus": "included",
          "quantity": null,
          "unit": null,
          "specification": null,
          "note": null,
          "sortOrder": 12
        },
        {
          "id": "quote-c-13",
          "categoryId": "protection",
          "rawLabel": "養生",
          "amountYen": 45000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 13
        },
        {
          "id": "quote-c-14",
          "categoryId": "machinery_transport",
          "rawLabel": "重機回送",
          "amountYen": 55000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 14
        },
        {
          "id": "quote-c-15",
          "categoryId": "overhead",
          "rawLabel": "諸経費",
          "amountYen": 140000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 15
        },
        {
          "id": "quote-c-16",
          "categoryId": "application",
          "rawLabel": "申請",
          "amountYen": 35000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 16
        },
        {
          "id": "quote-c-17",
          "categoryId": "discount",
          "rawLabel": "値引き",
          "amountYen": -70000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 17
        },
        {
          "id": "quote-c-18",
          "categoryId": "tax",
          "rawLabel": "消費税",
          "amountYen": 275000,
          "inclusionStatus": "included",
          "quantity": 1.0,
          "unit": "式",
          "specification": null,
          "note": null,
          "sortOrder": 18
        }
      ]
    }
  ]
}
    """
}
