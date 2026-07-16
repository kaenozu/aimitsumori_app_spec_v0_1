/// ファイルパス: lib/domain/normalizer.dart
/// 見積明細を共通カテゴリへ正規化するロジック
/// 関連ファイル: lib/models.dart, lib/data/category_master.dart

import '../models.dart';
import '../data/category_master.dart';

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
        uncertaintyReasons: ['見積明細に記載がありません'],
      );
    }

    final reasons = <String>[];
    final distinctStatuses = items.map((i) => i.inclusionStatus).toSet().toList();
    final status = distinctStatuses.length == 1
        ? distinctStatuses.first
        : (() {
            reasons.add('同じカテゴリ内で含有状態が一致していません');
            return InclusionStatus.unknown;
          })();

    final int? amount;
    if (items.every((i) => i.amountYen == null)) {
      amount = null;
    } else if (items.any((i) => i.amountYen == null)) {
      reasons.add('金額未記載の明細を含みます');
      amount = items.where((i) => i.amountYen != null).fold<int>(0, (sum, i) => sum + i.amountYen!);
    } else {
      amount = items.fold<int>(0, (sum, i) => sum + i.amountYen!);
    }

    final quantityValues = items.where((i) => i.quantity != null).map((i) => i.quantity!).toSet().toList();
    final unitValues = items.where((i) => i.unit?.trim().isNotEmpty == true).map((i) => i.unit!.trim()).toSet().toList();
    final quantity = quantityValues.length == 1 ? quantityValues.first : null;
    final unit = unitValues.length == 1 ? unitValues.first : null;
    if (category.quantityExpected && (quantity == null || unit == null)) {
      reasons.add('数量または単位が不明です');
    }
    if (quantityValues.length > 1 || unitValues.length > 1) {
      reasons.add('複数明細の数量・単位を単一値へ統合できません');
    }

    final specificationValues = items
        .where((i) => i.specification?.trim().isNotEmpty == true)
        .map((i) => i.specification!.trim())
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
      sourceLineItemIds: items.map((i) => i.id).toList(),
      uncertaintyReasons: reasons.toSet().toList(),
    );
  }
}
