/// ファイルパス: lib/comparison_engine.dart
/// 比較レポート生成エンジン。
library;

import 'package:intl/intl.dart';

import 'data/category_master.dart';
import 'models.dart';

class ComparisonEngine {
  ComparisonReport compare({
    required Project project,
    required List<NormalizedQuote> normalizedQuotes,
    required List<ClarificationQuestion> questions,
  }) {
    final quoteIds = normalizedQuotes.map((quote) => quote.quoteId).toList();
    if (quoteIds.toSet().length != quoteIds.length) {
      throw ArgumentError('比較対象のquoteIdが重複しています。');
    }
    for (final quote in normalizedQuotes) {
      final categoryIds = quote.lines.map((line) => line.category.id).toList();
      if (categoryIds.toSet().length != categoryIds.length) {
        throw ArgumentError('同じ見積内でカテゴリが重複しています: ${quote.quoteId}');
      }
    }

    final snapshots = normalizedQuotes.map((quote) {
      return QuoteSnapshot(
        quoteId: quote.quoteId,
        contractorName: quote.contractorName,
        totalAmountYen: quote.totalAmountYen,
        includedCategoryCount: quote.lines
            .where((line) => line.inclusionStatus == InclusionStatus.included)
            .length,
        separateCategoryNames: quote.lines
            .where((line) => line.inclusionStatus == InclusionStatus.separate)
            .map((line) => line.category.nameJa)
            .toList(growable: false),
        optionalCategoryNames: quote.lines
            .where((line) => line.inclusionStatus == InclusionStatus.optional)
            .map((line) => line.category.nameJa)
            .toList(growable: false),
        unknownCategoryNames: quote.lines
            .where((line) => line.inclusionStatus == InclusionStatus.unknown)
            .map((line) => line.category.nameJa)
            .toList(growable: false),
        uncertaintyCount: quote.lines.fold<int>(
          0,
          (sum, line) => sum + line.uncertaintyReasons.length,
        ),
      );
    }).toList(growable: false);

    final comparisons = CategoryMaster.categories.map((category) {
      return CategoryComparison(
        category: category,
        cells: normalizedQuotes.map((quote) {
          final matching = quote.lines.where(
            (value) => value.category.id == category.id,
          );
          final line = matching.isEmpty
              ? NormalizedLine(
                  category: category,
                  inclusionStatus: InclusionStatus.unknown,
                  uncertaintyReasons: const ['正規化結果にカテゴリがありません'],
                )
              : matching.single;
          return ComparisonCell(
            quoteId: quote.quoteId,
            contractorName: quote.contractorName,
            inclusionStatus: line.inclusionStatus,
            amountYen: line.amountYen,
            quantity: line.quantity,
            unit: line.unit,
            specification: line.specification,
            uncertaintyReasons: line.uncertaintyReasons,
          );
        }).toList(growable: false),
      );
    }).toList(growable: false);

    final summary = _buildThreeLineSummary(snapshots, questions);
    if (summary.length != 3) {
      throw StateError('比較サマリーは3行である必要があります。');
    }

    return ComparisonReport(
      projectId: project.id,
      projectName: project.name,
      quoteSnapshots: snapshots,
      categoryComparisons: comparisons,
      summaryLines: summary,
      clarificationQuestions: questions,
    );
  }

  List<String> _buildThreeLineSummary(
    List<QuoteSnapshot> snapshots,
    List<ClarificationQuestion> questions,
  ) {
    if (snapshots.isEmpty) {
      return const [
        '見積総額: 見積は未登録です。',
        '範囲差: 比較対象がないため判定できません。',
        '要確認: まず見積書を登録してください。質問テンプレートは0件です。',
      ];
    }

    final totalText = snapshots
        .map(
          (snapshot) =>
              '${snapshot.contractorName} ${_formatYen(snapshot.totalAmountYen)}',
        )
        .join(' / ');
    final knownTotals = snapshots
        .where((snapshot) => snapshot.totalAmountYen != null)
        .map((snapshot) => snapshot.totalAmountYen!)
        .toList(growable: false);
    final spreadText = knownTotals.length >= 2
        ? '、提示総額の幅は${_formatYen(knownTotals.reduce(_max) - knownTotals.reduce(_min))}'
        : '、総額差は算出不能';

    final scopeText = snapshots
        .map(
          (snapshot) =>
              '${snapshot.contractorName} 別途${snapshot.separateCategoryNames.length}件・'
              '任意${snapshot.optionalCategoryNames.length}件',
        )
        .join(' / ');
    final unknownText = snapshots
        .map(
          (snapshot) =>
              '${snapshot.contractorName} 不明カテゴリ${snapshot.unknownCategoryNames.length}件・'
              '不確実点${snapshot.uncertaintyCount}件',
        )
        .join(' / ');

    return [
      '見積総額: $totalText$spreadText。',
      '範囲差: $scopeText。別途・任意項目は総額だけでは比較できません。',
      '要確認: $unknownText。質問テンプレート${questions.length}件を生成しました。',
    ];
  }

  int _max(int left, int right) => left > right ? left : right;
  int _min(int left, int right) => left < right ? left : right;

  String _formatYen(int? value) {
    if (value == null) return '不明';
    return '${NumberFormat('#,##0', 'ja_JP').format(value)}円';
  }
}
