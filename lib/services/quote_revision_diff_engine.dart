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
      final oldItems = [...?beforeItems[key]]
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      final newItems = [...?afterItems[key]]
        ..sort((left, right) => left.sortOrder.compareTo(right.sortOrder));
      final pairedCount = oldItems.length < newItems.length
          ? oldItems.length
          : newItems.length;

      for (var index = 0; index < pairedCount; index++) {
        _compareItem(oldItems[index], newItems[index], changes);
      }
      for (var index = pairedCount; index < oldItems.length; index++) {
        final item = oldItems[index];
        changes.add(
          QuoteLineChange(
            type: QuoteLineChangeType.removed,
            categoryId: item.categoryId,
            label: item.rawLabel,
            before: item,
          ),
        );
      }
      for (var index = pairedCount; index < newItems.length; index++) {
        final item = newItems[index];
        changes.add(
          QuoteLineChange(
            type: QuoteLineChangeType.added,
            categoryId: item.categoryId,
            label: item.rawLabel,
            after: item,
          ),
        );
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

  void _compareItem(
    QuoteLineItem oldItem,
    QuoteLineItem newItem,
    List<QuoteLineChange> changes,
  ) {
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
    if (!_sameNullableDouble(oldItem.quantity, newItem.quantity)) {
      add(QuoteLineChangeType.quantity);
    }
    if (_normalized(oldItem.unit) != _normalized(newItem.unit)) {
      add(QuoteLineChangeType.unit);
    }
    if (_normalized(oldItem.specification) !=
        _normalized(newItem.specification)) {
      add(QuoteLineChangeType.specification);
    }
    if (oldItem.inclusionStatus != newItem.inclusionStatus) {
      add(QuoteLineChangeType.inclusion);
    }
  }

  double? _unitPrice(QuoteLineItem item) {
    final amount = item.amountYen;
    final quantity = item.quantity;
    if (amount == null || quantity == null || quantity <= 0) return null;
    return amount / quantity;
  }

  bool _sameNullableDouble(double? left, double? right) {
    if (left == null || right == null) return left == right;
    final tolerance = (left.abs() * 0.0001).clamp(0.01, 1000.0);
    return (left - right).abs() <= tolerance;
  }

  String? _normalized(String? value) {
    final normalized = value?.trim().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Map<String, List<QuoteLineItem>> _group(List<QuoteLineItem> items) {
    final grouped = <String, List<QuoteLineItem>>{};
    for (final item in items) {
      final normalizedLabel =
          item.rawLabel.replaceAll(RegExp(r'\s+'), '').toLowerCase();
      grouped
          .putIfAbsent('${item.categoryId}|$normalizedLabel', () => [])
          .add(item);
    }
    return grouped;
  }
}
