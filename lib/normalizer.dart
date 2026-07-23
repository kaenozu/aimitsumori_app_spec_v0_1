/// ファイルパス: lib/normalizer.dart
/// 見積明細を共通カテゴリへ正規化するロジック。
library;

import 'data/category_master.dart';
import 'models.dart';
import 'unit_normalizer.dart';

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
            items: itemsByCategory[category.id] ?? const [],
          );
        }).toList(growable: false),
      );
    }).toList(growable: false);
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
    final distinctStatuses = items
        .map((item) => item.inclusionStatus)
        .toSet();
    final status = distinctStatuses.length == 1
        ? distinctStatuses.single
        : InclusionStatus.unknown;
    if (distinctStatuses.length > 1) {
      reasons.add('同じカテゴリ内で含有状態が一致していません');
    }

    final int? amount;
    if (items.every((item) => item.amountYen == null)) {
      amount = null;
    } else {
      if (items.any((item) => item.amountYen == null)) {
        reasons.add('金額未記載の明細を含むため、表示額は記載分のみです');
      }
      amount = items
          .where((item) => item.amountYen != null)
          .fold<int>(0, (sum, item) => sum + item.amountYen!);
    }

    final quantityItems = items.where((item) => item.quantity != null).toList();
    final normalizedUnits = items
        .map((item) => UnitNormalizer.normalize(item.unit))
        .whereType<String>()
        .toSet();

    double? quantity;
    String? unit;
    if (quantityItems.length != items.length) {
      if (quantityItems.isNotEmpty) {
        reasons.add('数量未記載の明細を含むため、数量を合算できません');
      }
    } else if (normalizedUnits.length == 1) {
      unit = normalizedUnits.single;
      quantity = quantityItems.fold<double>(
        0,
        (sum, item) => sum + item.quantity!,
      );
    } else if (normalizedUnits.isEmpty && items.length == 1) {
      quantity = items.single.quantity;
    } else {
      reasons.add('複数明細の単位が一致しないため、数量を合算できません');
    }

    if (category.quantityExpected && (quantity == null || unit == null)) {
      reasons.add('数量または単位が不明です');
    }

    final specificationValues = items
        .where((item) => item.specification?.trim().isNotEmpty == true)
        .map((item) => item.specification!.trim())
        .toSet();
    final specification = specificationValues.length == 1
        ? specificationValues.single
        : null;
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
      sourceLineItemIds: items.map((item) => item.id).toList(growable: false),
      uncertaintyReasons: reasons.toSet().toList(growable: false),
    );
  }
}
