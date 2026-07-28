/// ファイルパス: lib/data/sample_data.dart
/// 固定テストデータ（A社/B社/C社）
library;

import '../models.dart';

class SampleData {
  SampleData._();

  static Project project() {
    const createdAt = 1784160000000;
    return const Project(
      id: 'sample-exterior-001',
      name: '新築外構 3社相見積もり',
      status: ProjectStatus.needsReview,
      createdAtEpochMillis: createdAt,
      updatedAtEpochMillis: createdAt + 3000,
      quotes: [
        ContractorQuote(
          id: 'quote-a',
          contractorName: 'A社',
          totalAmountYen: 2530000,
          note: '提示総額は最も低いが、残土処分と排水が別途。',
          createdAtEpochMillis: createdAt + 1000,
          lineItems: [
            QuoteLineItem(
              id: 'quote-a-concrete',
              categoryId: 'concrete',
              rawLabel: '土間コンクリート',
              amountYen: 800000,
              inclusionStatus: InclusionStatus.included,
              quantity: 120,
              unit: '㎡',
              specification: '刷毛引き t=100mm・ワイヤーメッシュ',
              sortOrder: 1,
            ),
            QuoteLineItem(
              id: 'quote-a-soil',
              categoryId: 'soil_disposal',
              rawLabel: '残土処分',
              inclusionStatus: InclusionStatus.separate,
              sortOrder: 2,
            ),
            QuoteLineItem(
              id: 'quote-a-drainage',
              categoryId: 'drainage',
              rawLabel: '排水工事',
              inclusionStatus: InclusionStatus.separate,
              sortOrder: 3,
            ),
          ],
        ),
        ContractorQuote(
          id: 'quote-b',
          contractorName: 'B社',
          totalAmountYen: 3450000,
          note: '排水・残土処分を含む。',
          createdAtEpochMillis: createdAt + 2000,
          lineItems: [
            QuoteLineItem(
              id: 'quote-b-concrete',
              categoryId: 'concrete',
              rawLabel: '土間コンクリート工事',
              amountYen: 970000,
              inclusionStatus: InclusionStatus.included,
              quantity: 120,
              unit: '㎡',
              specification: '金鏝仕上げ t=100mm・ワイヤーメッシュ',
              sortOrder: 1,
            ),
            QuoteLineItem(
              id: 'quote-b-soil',
              categoryId: 'soil_disposal',
              rawLabel: '残土搬出処分',
              amountYen: 180000,
              inclusionStatus: InclusionStatus.included,
              sortOrder: 2,
            ),
            QuoteLineItem(
              id: 'quote-b-drainage',
              categoryId: 'drainage',
              rawLabel: '排水工事',
              amountYen: 260000,
              inclusionStatus: InclusionStatus.included,
              quantity: 1,
              unit: '式',
              specification: '雨水桝・配管接続を含む',
              sortOrder: 3,
            ),
          ],
        ),
        ContractorQuote(
          id: 'quote-c',
          contractorName: 'C社',
          totalAmountYen: 2785000,
          note: '一部の数量・仕様・含有範囲が未記載。',
          createdAtEpochMillis: createdAt + 3000,
          lineItems: [
            QuoteLineItem(
              id: 'quote-c-concrete',
              categoryId: 'concrete',
              rawLabel: 'コンクリート舗装',
              amountYen: 850000,
              inclusionStatus: InclusionStatus.included,
              sortOrder: 1,
            ),
            QuoteLineItem(
              id: 'quote-c-drainage',
              categoryId: 'drainage',
              rawLabel: '排水関連',
              inclusionStatus: InclusionStatus.unknown,
              sortOrder: 2,
            ),
          ],
        ),
      ],
    );
  }
}
