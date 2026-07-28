/// 過去の改訂版をDBへ保存せずに比較する読み取り専用画面。
library;

import 'package:flutter/material.dart';
import '../utils/formatting.dart';

import '../comparison_engine.dart';
import '../models.dart';
import '../normalizer.dart';
import '../question_generator.dart';

class RevisionComparisonScreen extends StatelessWidget {
  const RevisionComparisonScreen({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final normalized = Normalizer().normalize(project);
    final questions = QuestionGenerator().generate(
      project: project,
      normalizedQuotes: normalized,
    );
    final report = ComparisonEngine().compare(
      project: project,
      normalizedQuotes: normalized,
      questions: questions,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('改訂版を比較')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(project.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text('この画面は読み取り専用です。現在の案件データや比較結果は変更しません。'),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'サマリー',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  for (
                    var index = 0;
                    index < report.summaryLines.length;
                    index++
                  )
                    Text('${index + 1}. ${report.summaryLines[index]}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (final snapshot in report.quoteSnapshots)
            Card(
              child: ListTile(
                title: Text(snapshot.contractorName),
                subtitle: Text(
                  '総額 ${formatYen(snapshot.totalAmountYen)} / '
                  '見積内 ${snapshot.includedCategoryCount}カテゴリ / '
                  '不明 ${snapshot.unknownCategoryNames.length}カテゴリ',
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text('カテゴリ別比較', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final comparison in report.categoryComparisons)
            ExpansionTile(
              title: Text(comparison.category.nameJa),
              children: [
                for (final cell in comparison.cells)
                  ListTile(
                    title: Text(cell.contractorName),
                    subtitle: Text(
                      '${cell.inclusionStatus.labelJa} / '
                      '金額 ${formatYen(cell.amountYen)} / '
                      '数量 ${formatQuantity(cell.quantity, cell.unit)} / '
                      '仕様 ${cell.specification ?? "未入力"}'
                      '${cell.uncertaintyReasons.isEmpty ? "" : "\n確認: ${cell.uncertaintyReasons.join(" / ")}"}',
                    ),
                    isThreeLine: cell.uncertaintyReasons.isNotEmpty,
                  ),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            '確認質問 (${report.clarificationQuestions.length}件)',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (report.clarificationQuestions.isEmpty)
            const Card(child: ListTile(title: Text('確認質問はありません。')))
          else
            for (final question in report.clarificationQuestions)
              Card(
                child: ListTile(
                  title: Text(question.contractorName ?? '業者'),
                  subtitle: SelectableText(question.questionText),
                ),
              ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
