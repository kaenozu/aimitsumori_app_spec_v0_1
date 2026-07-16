/// ファイルパス: lib/comparison_engine.dart
/// 比較レポート生成エンジン
/// 関連ファイル: lib/models.dart, lib/data/category_master.dart
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
    assert(
      normalizedQuotes.map((quote) => quote.quoteId).toSet().length == normalizedQuotes.length,
      'quoteId must be unique',
    );

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
            .toList(),
        optionalCategoryNames: quote.lines
            .where((line) => line.inclusionStatus == InclusionStatus.optional)
            .map((line) => line.category.nameJa)
            .toList(),
        unknownCategoryNames: quote.lines
            .where((line) => line.inclusionStatus == InclusionStatus.unknown)
            .map((line) => line.category.nameJa)
            .toList(),
        uncertaintyCount: quote.lines.fold<int>(
          0,
          (sum, line) => sum + line.uncertaintyReasons.length,
        ),
      );
    }).toList();

    final comparisons = CategoryMaster.categories.map((category) {
      return CategoryComparison(
        category: category,
        cells: normalizedQuotes.map((quote) {
          final line = quote.lines.firstWhere(
            (value) => value.category.id == category.id,
          );
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
        }).toList(),
      );
    }).toList();

    final summary = _buildThreeLineSummary(snapshots, questions);
    assert(summary.length == 3, 'Summary must contain exactly three lines');

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
        .map((snapshot) => '${snapshot.contractorName} ${_formatYen(snapshot.totalAmountYen)}')
        .join(' / ');
    final knownTotals = snapshots
        .where((snapshot) => snapshot.totalAmountYen != null)
        .map((snapshot) => snapshot.totalAmountYen!)
        .toList();
    final spreadText = knownTotals.length >= 2
        ? '、提示総額の幅は${_formatYen(knownTotals.reduce((a, b) => a > b ? a : b) - knownTotals.reduce((a, b) => a < b ? a : b))}'
        : '、総額差は算出不能';

    final scopeText = snapshots
        .map(
          (snapshot) =>
              '${snapshot.contractorName} 別途${snapshot.separateCategoryNames.length}件・任意${snapshot.optionalCategoryNames.length}件',
        )
        .join(' / ');
    final unknownText = snapshots
        .map(
          (snapshot) =>
              '${snapshot.contractorName} 不明カテゴリ${snapshot.unknownCategoryNames.length}件・不確実点${snapshot.uncertaintyCount}件',
        )
        .join(' / ');

    return [
      '見積総額: $totalText$spreadText。',
      '範囲差: $scopeText。別途・任意項目は総額だけでは比較できません。',
      '要確認: $unknownText。質問テンプレート${questions.length}件を生成しました。',
    ];
  }

  String _formatYen(int? value) {
    if (value == null) return '不明';
    final formatter = NumberFormat('#,##0', 'ja_JP');
    return '${formatter.format(value)}円';
  }
}
