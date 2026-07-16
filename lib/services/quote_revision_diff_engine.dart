/// 任意の2改訂版から総額・明細・仕様・状態の差分を生成する。
library;

import '../models.dart';
import '../quote_revision_models.dart';

class QuoteRevisionDiffEngine {
  const QuoteRevisionDiffEngine();

  QuoteRevisionDiff compare(QuoteRevision before, QuoteRevision after) {
    final beforeItems = _group(before.quoteSnapshot.lineItems);
    final afterItems = _group(after.quoteSnapshot.lineItems);
    final keys = {...beforeItems.keys, ...afterItems.keys}.toList()..sort();
    final changes = <QuoteLineChange>[];

    for (final key in keys) {
      final oldItem = beforeItems[key];
      final newItem = afterItems[key];
      if (oldItem == null && newItem != null) {
        changes.add(
          QuoteLineChange(
            type: QuoteLineChangeType.added,
            categoryId: newItem.categoryId,
            label: newItem.rawLabel,
            after: newItem,
          ),
        );
        continue;
      }
      if (oldItem != null && newItem == null) {
        changes.add(
          QuoteLineChange(
            type: QuoteLineChangeType.removed,
            categoryId: oldItem.categoryId,
            label: oldItem.rawLabel,
            before: oldItem,
          ),
        );
        continue;
      }
      if (oldItem == null || newItem == null) continue;

      void add(
        QuoteLineChangeType type, {
        double? beforeUnitPriceYen,
        double? afterUnitPriceYen,
      }) {
        changes.add(
          QuoteLineChange(
            type: type,
            categoryId: newItem.categoryId,
            label: newItem.rawLabel,
            before: oldItem,
            after: newItem,
            beforeUnitPriceYen: beforeUnitPriceYen,
            afterUnitPriceYen: afterUnitPriceYen,
          ),
        );
      }

      if (oldItem.amountYen != newItem.amountYen) {
        add(QuoteLineChangeType.amount);
      }
      final oldUnitPrice = _unitPrice(oldItem);
      final newUnitPrice = _unitPrice(newItem);
      if (!_sameNullableDouble(oldUnitPrice, newUnitPrice)) {
        add(
          QuoteLineChangeType.unitPrice,
          beforeUnitPriceYen: oldUnitPrice,
          afterUnitPriceYen: newUnitPrice,
        );
      }
      if (oldItem.quantity != newItem.quantity) {
        add(QuoteLineChangeType.quantity);
      }
      if (oldItem.unit != newItem.unit) {
        add(QuoteLineChangeType.unit);
      }
      if (oldItem.specification != newItem.specification) {
        add(QuoteLineChangeType.specification);
      }
      if (oldItem.inclusionStatus != newItem.inclusionStatus) {
        add(QuoteLineChangeType.inclusion);
      }
    }

    final oldTotal = before.quoteSnapshot.totalAmountYen;
    final newTotal = after.quoteSnapshot.totalAmountYen;
    return QuoteRevisionDiff(
      before: before,
      after: after,
      totalDifferenceYen:
          oldTotal == null || newTotal == null ? null : newTotal - oldTotal,
      changes: changes,
    );
  }

  double? _unitPrice(QuoteLineItem item) {
    final amount = item.amountYen;
    final quantity = item.quantity;
    if (amount == null || quantity == null || quantity <= 0) return null;
    return amount / quantity;
  }

  bool _sameNullableDouble(double? left, double? right) {
    if (left == null || right == null) return left == right;
    return (left - right).abs() < 0.01;
  }

  Map<String, QuoteLineItem> _group(List<QuoteLineItem> items) {
    final grouped = <String, QuoteLineItem>{};
    for (final item in items) {
      final normalizedLabel =
          item.rawLabel.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      grouped['${item.categoryId}|$normalizedLabel'] = item;
    }
    return grouped;
  }
}
