library;

import 'package:flutter/material.dart';

import '../ocr_models.dart';
import 'ocr_crop_preview.dart';

class OcrReviewOverview extends StatelessWidget {
  const OcrReviewOverview({
    super.key,
    required this.bundle,
    required this.statuses,
    required this.onStatusChanged,
  });

  final OcrReviewBundle bundle;
  final Map<String, OcrReviewStatus> statuses;
  final void Function(String id, OcrReviewStatus status) onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final reviewLines = bundle.lines.where((line) => line.needsReview).toList();
    if (reviewLines.isEmpty && bundle.issues.isEmpty) {
      return Card(
        color: Theme.of(context).colorScheme.secondaryContainer,
        child: const ListTile(
          leading: Icon(Icons.verified_outlined),
          title: Text('OCR結果は自動確定できます'),
          subtitle: Text('信頼度・金額整合性に大きな問題は見つかりませんでした。'),
        ),
      );
    }

    final pending = reviewLines
            .where((line) =>
                (statuses[line.id] ?? line.initialStatus) == OcrReviewStatus.pending)
            .length +
        bundle.issues
            .where((issue) =>
                (statuses[issue.id] ?? issue.initialStatus) == OcrReviewStatus.pending)
            .length;
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.fact_check_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '要確認 $pending件',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('低信頼度・複数候補・計算不一致を確認してください。状態は端末内に保存されます。'),
            for (final issue in bundle.issues) ...[
              const Divider(),
              _IssueRow(
                issue: issue,
                status: statuses[issue.id] ?? issue.initialStatus,
                onChanged: (status) => onStatusChanged(issue.id, status),
              ),
            ],
            for (final line in reviewLines) ...[
              const Divider(),
              OcrLineReviewPanel(
                line: line,
                status: statuses[line.id] ?? line.initialStatus,
                onChanged: (status) => onStatusChanged(line.id, status),
                compact: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class OcrLineReviewPanel extends StatelessWidget {
  const OcrLineReviewPanel({
    super.key,
    required this.line,
    required this.status,
    required this.onChanged,
    this.compact = false,
  });

  final OcrRecognizedLine line;
  final OcrReviewStatus status;
  final ValueChanged<OcrReviewStatus> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final confidence = (line.confidence * 100).round();
    final category = (line.categoryConfidence * 100).round();
    final amount = (line.amountConfidence * 100).round();
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _ConfidenceChip(label: 'OCR $confidence%', value: line.confidence),
            _ConfidenceChip(label: 'カテゴリ $category%', value: line.categoryConfidence),
            _ConfidenceChip(label: '金額 $amount%', value: line.amountConfidence),
            Chip(
              avatar: Icon(
                status == OcrReviewStatus.pending
                    ? Icons.help_outline
                    : status == OcrReviewStatus.confirmed
                        ? Icons.check_circle_outline
                        : Icons.auto_awesome_outlined,
                size: 18,
              ),
              label: Text(status.labelJa),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          line.rawText,
          maxLines: compact ? 2 : 4,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        OcrCropPreview(line: line, height: compact ? 72 : 92),
        if (status == OcrReviewStatus.pending) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              onPressed: () => onChanged(OcrReviewStatus.confirmed),
              icon: const Icon(Icons.check),
              label: const Text('確認済みにする'),
            ),
          ),
        ],
      ],
    );
    return Semantics(
      container: true,
      label: 'OCR要確認箇所、${status.labelJa}',
      child: body,
    );
  }
}

class _IssueRow extends StatelessWidget {
  const _IssueRow({
    required this.issue,
    required this.status,
    required this.onChanged,
  });

  final OcrReviewIssue issue;
  final OcrReviewStatus status;
  final ValueChanged<OcrReviewStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final isCritical = issue.severity == OcrReviewSeverity.critical;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          isCritical ? Icons.error_outline : Icons.warning_amber_outlined,
          color: isCritical
              ? Theme.of(context).colorScheme.error
              : Theme.of(context).colorScheme.tertiary,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(issue.message),
              const SizedBox(height: 6),
              if (status == OcrReviewStatus.pending)
                FilledButton.tonal(
                  onPressed: () => onChanged(OcrReviewStatus.confirmed),
                  child: const Text('内容を確認しました'),
                )
              else
                Text('状態: ${status.labelJa}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    final icon = value >= 0.9
        ? Icons.check_circle_outline
        : value >= 0.75
            ? Icons.info_outline
            : Icons.warning_amber_outlined;
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
