library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../ocr_models.dart';
import '../repositories/project_repository.dart';
import '../services/batch_ocr_service.dart';
import '../services/ocr_review_store.dart';
import '../widgets/ocr_review_widgets.dart';

class ScannerOcrReviewScreen extends StatefulWidget {
  const ScannerOcrReviewScreen({
    super.key,
    required this.project,
    required this.result,
    this.repository,
    this.reviewStore,
  });

  final Project project;
  final BatchOcrResult result;
  final ProjectRepository? repository;
  final OcrReviewStore? reviewStore;

  @override
  State<ScannerOcrReviewScreen> createState() =>
      _ScannerOcrReviewScreenState();
}

class _ScannerOcrReviewScreenState extends State<ScannerOcrReviewScreen> {
  late final ProjectRepository _repository =
      widget.repository ?? ProjectRepository.instance;
  late final OcrReviewStore _reviewStore =
      widget.reviewStore ?? OcrReviewStore();
  late final TextEditingController _contractorController =
      TextEditingController(text: widget.result.quote.contractorName);
  late final TextEditingController _totalController = TextEditingController(
    text: widget.result.quote.totalAmountYen == null
        ? ''
        : NumberFormat('#,##0', 'ja_JP')
            .format(widget.result.quote.totalAmountYen),
  );
  late Map<String, OcrReviewStatus> _statuses = {
    for (final line in widget.result.reviewBundle.lines)
      line.id: line.initialStatus,
    for (final issue in widget.result.reviewBundle.issues)
      issue.id: issue.initialStatus,
  };

  bool _statusesLoaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatuses());
  }

  @override
  void dispose() {
    _contractorController.dispose();
    _totalController.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    try {
      final persisted =
          await _reviewStore.load(widget.result.quote.sourcePath);
      if (!mounted) return;
      setState(() {
        _statuses = {..._statuses, ...persisted};
        _statusesLoaded = true;
      });
    } catch (error) {
      debugPrint('OCR review state load failed: $error');
      if (mounted) setState(() => _statusesLoaded = true);
    }
  }

  void _setStatus(String id, OcrReviewStatus status) {
    if (!_statusesLoaded) return;
    setState(() => _statuses[id] = status);
    unawaited(
      _reviewStore.save(widget.result.quote.sourcePath, _statuses),
    );
  }

  int get _criticalPendingCount {
    final bundle = widget.result.reviewBundle;
    final criticalLines = bundle.lines.where(
      (line) =>
          line.severity == OcrReviewSeverity.critical &&
          (_statuses[line.id] ?? line.initialStatus) ==
              OcrReviewStatus.pending,
    );
    final criticalIssues = bundle.issues.where(
      (issue) =>
          issue.severity == OcrReviewSeverity.critical &&
          (_statuses[issue.id] ?? issue.initialStatus) ==
              OcrReviewStatus.pending,
    );
    return criticalLines.length + criticalIssues.length;
  }

  Future<bool> _confirmCriticalItems() async {
    final count = _criticalPendingCount;
    if (count == 0) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.priority_high_outlined),
            title: const Text('優先度1の未確認箇所があります'),
            content: Text(
              '合計不一致や数量×単価不一致など、$count件が未確認です。元画像と照合してからの保存を推奨します。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('確認に戻る'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('未確認のまま保存'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _save() async {
    if (!_statusesLoaded || _saving || !await _confirmCriticalItems()) return;
    final contractor = _contractorController.text.trim();
    if (contractor.isEmpty) {
      setState(() => _error = '業者名を入力してください。');
      return;
    }
    final normalizedTotal =
        _totalController.text.replaceAll(RegExp(r'[^0-9-]'), '');
    final total = normalizedTotal.isEmpty ? null : int.tryParse(normalizedTotal);
    if (normalizedTotal.isNotEmpty && total == null) {
      setState(() => _error = '合計金額を数値で入力してください。');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final source = widget.result.quote;
      final corrected = RawQuoteData(
        contractorName: contractor,
        totalAmountYen: total,
        lineItems: source.lineItems,
        extractedText: source.extractedText,
        sourcePath: source.sourcePath,
        createdAtEpochMillis: source.createdAtEpochMillis,
      );
      await _repository.saveQuote(
        widget.project.id,
        corrected.toContractorQuote(),
      );
      await _reviewStore.save(source.sourcePath, _statuses);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Scanned quote save failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quote = widget.result.quote;
    final bundle = widget.result.reviewBundle;
    final reviewCount = bundle.lines.where((line) => line.needsReview).length +
        bundle.issues.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OCR結果を確認'),
        actions: [
          IconButton(
            tooltip: '確認して保存',
            onPressed: _saving || !_statusesLoaded ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_statusesLoaded) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: 12),
            const Text('保存済みの確認状態を読み込んでいます…'),
            const SizedBox(height: 12),
          ],
          Card(
            color: Theme.of(context).colorScheme.tertiaryContainer,
            child: ListTile(
              leading: const Icon(Icons.priority_high),
              title: Text('優先度1の要確認箇所: $reviewCount件'),
              subtitle: const Text(
                '撮影した原画像を保持し、OCR信頼度が低い箇所を画像と並べて確認できます。',
              ),
            ),
          ),
          const SizedBox(height: 12),
          OcrReviewOverview(
            bundle: bundle,
            statuses: _statuses,
            onStatusChanged: _setStatus,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _contractorController,
            decoration: const InputDecoration(
              labelText: '業者名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _totalController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '提示総額（税込・円）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '抽出結果',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('撮影ページ: ${quote.sourcePath.split('|').length}ページ'),
                  Text('抽出明細: ${quote.lineItems.length}件'),
                  const SizedBox(height: 8),
                  const Text(
                    '保存後は比較画面で差異と不明点を確認できます。',
                  ),
                ],
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving || !_statusesLoaded ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中…' : '確認して保存'),
          ),
        ],
      ),
    );
  }
}
