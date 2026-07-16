/// ファイルパス: lib/normalizer.dart
/// 見積明細を共通カテゴリへ正規化するロジック
/// 関連ファイル: lib/models.dart, lib/data/category_master.dart
library;

import 'data/category_master.dart';
import 'models.dart';

class Normalizer {
  List<NormalizedQuote> normalize(Project project) {
    return project.quotes.map((quote) {
      final itemsByCategory = <String, List<QuoteLineItem>>{};
      for (final item in quote.lineItems) {
        itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
      }
      return NormalizedQuote(
        quoteId: quote.id,
        contractorName: quote.contractorName,
        totalAmountYen: quote.totalAmountYen,
        lines: CategoryMaster.categories.map((category) {
          return _normalizeCategory(
            category: category,
            items: itemsByCategory[category.id] ?? [],
          );
        }).toList(),
      );
    }).toList();
  }

  NormalizedLine _normalizeCategory({
    required CategoryDefinition category,
    required List<QuoteLineItem> items,
  }) {
    if (items.isEmpty) {
      return NormalizedLine(
        category: category,
        inclusionStatus: InclusionStatus.unknown,
        uncertaintyReasons: const ['見積明細に記載がありません'],
      );
    }

    final reasons = <String>[];
    final distinctStatuses = items.map((item) => item.inclusionStatus).toSet().toList();
    final status = distinctStatuses.length == 1
        ? distinctStatuses.first
        : (() {
            reasons.add('同じカテゴリ内で含有状態が一致していません');
            return InclusionStatus.unknown;
          })();

    final int? amount;
    if (items.every((item) => item.amountYen == null)) {
      amount = null;
    } else if (items.any((item) => item.amountYen == null)) {
      reasons.add('金額未記載の明細を含みます');
      amount = items
          .where((item) => item.amountYen != null)
          .fold<int>(0, (sum, item) => sum + item.amountYen!);
    } else {
      amount = items.fold<int>(0, (sum, item) => sum + item.amountYen!);
    }

    final quantityValues = items
        .where((item) => item.quantity != null)
        .map((item) => item.quantity!)
        .toSet()
        .toList();
    final unitValues = items
        .where((item) => item.unit?.trim().isNotEmpty == true)
        .map((item) => item.unit!.trim())
        .toSet()
        .toList();
    final quantity = quantityValues.length == 1 ? quantityValues.first : null;
    final unit = unitValues.length == 1 ? unitValues.first : null;
    if (category.quantityExpected && (quantity == null || unit == null)) {
      reasons.add('数量または単位が不明です');
    }
    if (quantityValues.length > 1 || unitValues.length > 1) {
      reasons.add('複数明細の数量・単位を単一値へ統合できません');
    }

    final specificationValues = items
        .where((item) => item.specification?.trim().isNotEmpty == true)
        .map((item) => item.specification!.trim())
        .toSet()
        .toList();
    final specification = specificationValues.length == 1 ? specificationValues.first : null;
    if (category.specificationExpected && specification == null) {
      reasons.add('仕様・型番が不明です');
    }
    if (specificationValues.length > 1) {
      reasons.add('複数の仕様・型番が混在しています');
    }
    if (status == InclusionStatus.unknown) {
      reasons.add('見積に含むかどうか不明です');
    }

    return NormalizedLine(
      category: category,
      inclusionStatus: status,
      amountYen: amount,
      quantity: quantity,
      unit: unit,
      specification: specification,
      sourceLineItemIds: items.map((item) => item.id).toList(),
      uncertaintyReasons: reasons.toSet().toList(),
    );
  }
}
