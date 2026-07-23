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
      final oldItems = [...?beforeItems[key]];
      final newItems = [...?afterItems[key]];
      final matches = _matchItems(oldItems, newItems);

      for (final match in matches.pairs) {
        _compareItem(match.before, match.after, changes);
      }
      for (final item in matches.removed) {
        changes.add(
          QuoteLineChange(
            type: QuoteLineChangeType.removed,
            categoryId: item.categoryId,
            label: item.rawLabel,
            before: item,
          ),
        );
      }
      for (final item in matches.added) {
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
      totalDifferenceYen: oldTotal == null || newTotal == null
          ? null
          : newTotal - oldTotal,
      changes: changes,
    );
  }

  _LineMatches _matchItems(
    List<QuoteLineItem> oldItems,
    List<QuoteLineItem> newItems,
  ) {
    final remainingOld = [...oldItems];
    final remainingNew = [...newItems];
    final pairs = <_LinePair>[];

    // 同じIDを維持している編集ではIDを最優先する。
    for (final oldItem in [...remainingOld]) {
      final newIndex = remainingNew.indexWhere(
        (newItem) => newItem.id == oldItem.id,
      );
      if (newIndex < 0) continue;
      pairs.add(_LinePair(oldItem, remainingNew.removeAt(newIndex)));
      remainingOld.remove(oldItem);
    }

    // OCR再取込のようにIDが変わる場合は、内容が最も近い行を対応付ける。
    while (remainingOld.isNotEmpty && remainingNew.isNotEmpty) {
      var bestOldIndex = 0;
      var bestNewIndex = 0;
      var bestCost = double.infinity;
      for (var oldIndex = 0; oldIndex < remainingOld.length; oldIndex++) {
        for (var newIndex = 0; newIndex < remainingNew.length; newIndex++) {
          final cost = _matchCost(
            remainingOld[oldIndex],
            remainingNew[newIndex],
          );
          if (cost < bestCost) {
            bestCost = cost;
            bestOldIndex = oldIndex;
            bestNewIndex = newIndex;
          }
        }
      }
      pairs.add(
        _LinePair(
          remainingOld.removeAt(bestOldIndex),
          remainingNew.removeAt(bestNewIndex),
        ),
      );
    }

    pairs.sort((left, right) {
      final order = left.before.sortOrder.compareTo(right.before.sortOrder);
      if (order != 0) return order;
      return left.before.id.compareTo(right.before.id);
    });
    remainingOld.sort(_sortItems);
    remainingNew.sort(_sortItems);
    return _LineMatches(
      pairs: pairs,
      removed: remainingOld,
      added: remainingNew,
    );
  }

  double _matchCost(QuoteLineItem before, QuoteLineItem after) {
    var cost = 0.0;
    if (before.inclusionStatus != after.inclusionStatus) cost += 8;
    if (_normalized(before.unit) != _normalized(after.unit)) cost += 4;
    if (_normalized(before.specification) != _normalized(after.specification)) {
      cost += 2;
    }
    cost += _relativeDifference(before.amountYen, after.amountYen) * 2;
    cost += _relativeDifference(before.quantity, after.quantity);
    return cost;
  }

  double _relativeDifference(num? left, num? right) {
    if (left == null || right == null) return left == right ? 0 : 1;
    final scale = [left.abs(), right.abs(), 1].reduce((a, b) => a > b ? a : b);
    return ((left - right).abs() / scale).clamp(0, 1).toDouble();
  }

  int _sortItems(QuoteLineItem left, QuoteLineItem right) {
    final order = left.sortOrder.compareTo(right.sortOrder);
    return order != 0 ? order : left.id.compareTo(right.id);
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
    final tolerance = (left.abs() * 0.0001).clamp(0.01, 1000.0).toDouble();
    return (left - right).abs() <= tolerance;
  }

  String? _normalized(String? value) {
    final normalized = value
        ?.trim()
        .replaceAll(RegExp(r'\s+'), '')
        .toLowerCase();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  Map<String, List<QuoteLineItem>> _group(List<QuoteLineItem> items) {
    final grouped = <String, List<QuoteLineItem>>{};
    for (final item in items) {
      final normalizedLabel = item.rawLabel
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
      grouped
          .putIfAbsent('${item.categoryId}|$normalizedLabel', () => [])
          .add(item);
    }
    return grouped;
  }
}

class _LinePair {
  const _LinePair(this.before, this.after);

  final QuoteLineItem before;
  final QuoteLineItem after;
}

class _LineMatches {
  const _LineMatches({
    required this.pairs,
    required this.removed,
    required this.added,
  });

  final List<_LinePair> pairs;
  final List<QuoteLineItem> removed;
  final List<QuoteLineItem> added;
}
