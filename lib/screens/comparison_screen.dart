/// ファイルパス: lib/screens/comparison_screen.dart
/// 比較画面 - 3行サマリー、3社比較表、質問テンプレート
/// 関連ファイル: lib/models.dart, lib/normalizer.dart, lib/comparison_engine.dart, lib/question_generator.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../normalizer.dart';
import '../comparison_engine.dart';
import '../question_generator.dart';

class ComparisonScreen extends StatefulWidget {
  final Project project;
  const ComparisonScreen({super.key, required this.project});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late ComparisonReport _report;

  @override
  void initState() {
    super.initState();
    _report = _generateReport();
  }

  ComparisonReport _generateReport() {
    final normalizer = Normalizer();
    final engine = ComparisonEngine();
    final qg = QuestionGenerator();

    final normalized = normalizer.normalize(widget.project);
    final questions = qg.generate(project: widget.project, normalizedQuotes: normalized);
    return engine.compare(
      project: widget.project,
      normalizedQuotes: normalized,
      questions: questions,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('比較'),
        leading: IconButton(
          icon: const Text('戻る', style: TextStyle(fontSize: 14)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(_report.projectName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('順位・総合点は付けず、条件差と不明点を確認します。', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 16),
          _SummaryCard(lines: _report.summaryLines),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _report.quoteSnapshots.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) => _SnapshotCard(snapshot: _report.quoteSnapshots[i]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('18カテゴリ比較', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._report.categoryComparisons.map((c) => _CategoryCard(comparison: c)),
          const SizedBox(height: 16),
          Text('確認質問テンプレート (${_report.clarificationQuestions.length}件)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._report.clarificationQuestions.map((q) => _QuestionCard(question: q)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<String> lines;
  const _SummaryCard({required this.lines});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3行サマリー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...lines.asMap().entries.map((e) => Text('${e.key + 1}. ${e.value}')),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  final QuoteSnapshot snapshot;
  const _SnapshotCard({required this.snapshot});

  String _fmt(int? v) => v != null ? NumberFormat('#,##0', 'ja_JP').format(v) : '不明';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(snapshot.contractorName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('提示総額: ${_fmt(snapshot.totalAmountYen)}円'),
              Text('見積内: ${snapshot.includedCategoryCount}カテゴリ'),
              Text('別途: ${snapshot.separateCategoryNames.isEmpty ? "なし" : snapshot.separateCategoryNames.join(", ")}'),
              Text('任意: ${snapshot.optionalCategoryNames.isEmpty ? "なし" : snapshot.optionalCategoryNames.join(", ")}'),
              Text('含有不明: ${snapshot.unknownCategoryNames.length}カテゴリ'),
              Text('不確実点: ${snapshot.uncertaintyCount}件'),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final CategoryComparison comparison;
  const _CategoryCard({required this.comparison});

  String _fmt(int? v) => v != null ? NumberFormat('#,##0', 'ja_JP').format(v) : '不明';

  String _fmtQty(double? q, String? u) {
    if (q == null || u == null) return '不明';
    return q == q.roundToDouble() ? '${q.toInt()} $u' : '$q $u';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(comparison.category.nameJa, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const Divider(),
            ...comparison.cells.asMap().entries.map((e) {
              final cell = e.value;
              final isLast = e.key == comparison.cells.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(cell.contractorName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Chip(label: Text(cell.inclusionStatus.labelJa, style: const TextStyle(fontSize: 11))),
                      ],
                    ),
                    Text('金額: ${_fmt(cell.amountYen)}円'),
                    Text('数量: ${_fmtQty(cell.quantity, cell.unit)}'),
                    Text('仕様: ${cell.specification ?? "不明"}'),
                    if (cell.uncertaintyReasons.isNotEmpty)
                      Text(
                        '不明・確認: ${cell.uncertaintyReasons.join(" / ")}',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final ClarificationQuestion question;
  const _QuestionCard({required this.question});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(question.templateKey, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Text(question.questionText),
          ],
        ),
      ),
    );
  }
}
