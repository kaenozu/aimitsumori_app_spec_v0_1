/// ファイルパス: lib/screens/quote_input_screen.dart
/// 目的: 見積を取り込み、OCR結果と明細を編集して保存する。
/// 存在理由: OCR結果を利用者が確認・修正する編集画面のため。
/// 関連ファイル: ocr_service.dart, project_repository.dart, quote_revision_screen.dart
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/category_master.dart';
import '../models.dart';
import '../ocr_models.dart';
import '../quote_revision_models.dart';
import '../repositories/project_repository.dart';
import '../services/id_generator.dart';
import '../services/ocr_review_store.dart';
import '../services/ocr_service.dart';
import '../services/value_normalizer.dart';
import '../widgets/ocr_review_widgets.dart';

class QuoteInputScreen extends StatefulWidget {
  const QuoteInputScreen({
    super.key,
    required this.project,
    this.repository,
    this.ocrService,
    this.reviewStore,
    this.revisionIntent = const QuoteImportIntent.newQuote(),
  });

  final Project project;
  final ProjectRepository? repository;
  final OcrService? ocrService;
  final OcrReviewStore? reviewStore;
  final QuoteImportIntent revisionIntent;

  @override
  State<QuoteInputScreen> createState() => _QuoteInputScreenState();
}

class _QuoteInputScreenState extends State<QuoteInputScreen> {
  late final bool _ownsOcrService = widget.ocrService == null;
  late final OcrService _ocrService = widget.ocrService ?? OcrService();
  late final OcrReviewStore _reviewStore =
      widget.reviewStore ?? OcrReviewStore();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _contractorController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  RawQuoteData? _rawQuote;
  OcrReviewBundle? _reviewBundle;
  String? _documentReviewKey;
  Map<String, OcrReviewStatus> _reviewStatuses = {};
  List<_EditableLineItem> _editableItems = [];
  bool _processing = false;
  bool _saving = false;
  String? _error;

  ProjectRepository get _repository =>
      widget.repository ?? ProjectRepository.instance;

  @override
  void dispose() {
    _contractorController.dispose();
    _totalController.dispose();
    for (final item in _editableItems) {
      item.dispose();
    }
    if (_ownsOcrService) unawaited(_ocrService.dispose());
    super.dispose();
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: false,
      );
      final path = result?.files.single.path;
      if (path != null) await _process(path);
    } catch (error, stackTrace) {
      debugPrint('PDF picker failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = 'PDFを開けませんでした。ファイルを選び直してください。');
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                key: const ValueKey('quote-camera-option'),
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                key: const ValueKey('quote-gallery-option'),
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('写真ライブラリから選択'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null) return;

      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 95,
        requestFullMetadata: false,
      );
      if (image != null) await _process(image.path);
    } catch (error, stackTrace) {
      debugPrint('Image picker failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = '写真を開けませんでした。カメラ・写真へのアクセス権限を確認してください。');
    }
  }

  Future<void> _process(String path) async {
    setState(() {
      _processing = true;
      _error = null;
      _rawQuote = null;
      _reviewBundle = null;
      _documentReviewKey = null;
      _reviewStatuses = {};
      _replaceEditableItems(const [], const []);
    });

    try {
      final result = await _ocrService.extractQuote(path);
      final bundle =
          _ocrService.lastReviewBundle ??
          const OcrReviewBundle(lines: [], issues: []);
      final documentKey = _ocrService.lastSourceFileHash ?? result.sourcePath;
      final persisted = await _reviewStore.load(documentKey);
      final statuses = <String, OcrReviewStatus>{
        for (final line in bundle.lines) line.id: line.initialStatus,
        for (final issue in bundle.issues) issue.id: issue.initialStatus,
        ...persisted,
      };
      if (!mounted) return;
      _contractorController.text = result.contractorName;
      _totalController.text = result.totalAmountYen == null
          ? ''
          : NumberFormat('#,##0', 'ja_JP').format(result.totalAmountYen);
      setState(() {
        _rawQuote = result;
        _reviewBundle = bundle;
        _documentReviewKey = documentKey;
        _reviewStatuses = statuses;
        _replaceEditableItems(result.lineItems, bundle.lines);
      });
    } on OcrException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error, stackTrace) {
      debugPrint('OCR processing failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = '文字の読み取りに失敗しました。画像の明るさ・向き・解像度を確認して、もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _replaceEditableItems(
    List<RawQuoteLineItem> items,
    List<OcrRecognizedLine> recognizedLines,
  ) {
    for (final item in _editableItems) {
      item.dispose();
    }
    final remaining = List<OcrRecognizedLine>.from(recognizedLines);
    _editableItems = items.map((item) {
      final matchIndex = remaining.indexWhere(
        (line) =>
            line.rawText == item.rawLabel &&
            line.categoryCandidates.contains(item.categoryId),
      );
      final sourceLine = matchIndex < 0 ? null : remaining.removeAt(matchIndex);
      return _EditableLineItem.fromModel(item, sourceLine: sourceLine);
    }).toList();
  }

  void _addLineItem() {
    setState(() => _editableItems.add(_EditableLineItem.empty()));
  }

  void _removeLineItem(int index) {
    setState(() {
      final removed = _editableItems.removeAt(index);
      removed.dispose();
    });
  }

  OcrReviewStatus _statusFor(OcrRecognizedLine line) =>
      _reviewStatuses[line.id] ?? line.initialStatus;

  void _setReviewStatus(String id, OcrReviewStatus status) {
    final documentKey = _documentReviewKey;
    setState(() => _reviewStatuses[id] = status);
    if (documentKey != null) {
      unawaited(_reviewStore.save(documentKey, _reviewStatuses));
    }
  }

  int _criticalPendingCount() {
    final bundle = _reviewBundle;
    if (bundle == null) return 0;
    final criticalLines = bundle.lines.where(
      (line) =>
          line.severity == OcrReviewSeverity.critical &&
          (_reviewStatuses[line.id] ?? line.initialStatus) ==
              OcrReviewStatus.pending,
    );
    final criticalIssues = bundle.issues.where(
      (issue) =>
          issue.severity == OcrReviewSeverity.critical &&
          (_reviewStatuses[issue.id] ?? issue.initialStatus) ==
              OcrReviewStatus.pending,
    );
    return criticalLines.length + criticalIssues.length;
  }

  Future<bool> _confirmSaveWithCriticalItems() async {
    final count = _criticalPendingCount();
    if (count == 0) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(Icons.warning_amber_outlined),
            title: const Text('重大な未確認項目があります'),
            content: Text('合計不一致や数量×単価不一致など、$count件が未確認です。保存前の確認を推奨します。'),
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
    final rawQuote = _rawQuote;
    if (rawQuote == null || _saving) return;
    if (!await _confirmSaveWithCriticalItems()) return;

    final contractorName = _contractorController.text.trim();
    if (contractorName.isEmpty) {
      setState(() => _error = '業者名を入力してください。');
      return;
    }
    if (contractorName.length > 100) {
      setState(() => _error = '業者名は100文字以内で入力してください。');
      return;
    }

    final totalText = _totalController.text.trim();
    final totalAmount = totalText.isEmpty
        ? null
        : LocalizedNumberParser.tryParseYen(totalText);
    if (totalText.isNotEmpty && totalAmount == null) {
      setState(() => _error = '合計金額は0以上の整数で入力してください。');
      return;
    }

    late final List<RawQuoteLineItem> lineItems;
    try {
      lineItems = [
        for (var index = 0; index < _editableItems.length; index++)
          _editableItems[index].toModel(index),
      ];
    } on FormatException catch (error) {
      setState(() => _error = error.message);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final corrected = RawQuoteData(
        contractorName: contractorName,
        totalAmountYen: totalAmount,
        lineItems: lineItems,
        extractedText: rawQuote.extractedText,
        sourcePath: rawQuote.sourcePath,
        createdAtEpochMillis: rawQuote.createdAtEpochMillis,
      );
      final generated = corrected.toContractorQuote(
        id: IdGenerator.prefixed('quote'),
      );
      final quote = ContractorQuote(
        id: generated.id,
        contractorName: generated.contractorName,
        totalAmountYen: generated.totalAmountYen,
        note: 'OCR取込',
        createdAtEpochMillis: generated.createdAtEpochMillis,
        lineItems: generated.lineItems,
      );
      await _repository.saveQuote(
        widget.project.id,
        quote,
        revisionIntent: widget.revisionIntent,
        sourceFileHash: _ocrService.lastSourceFileHash,
      );
      final documentKey = _documentReviewKey;
      if (documentKey != null) {
        await _reviewStore.save(documentKey, _reviewStatuses);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('見積を保存しました。')));
      Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Quote save failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rawQuote = _rawQuote;
    final reviewBundle = _reviewBundle;
    return Scaffold(
      appBar: AppBar(
        title: const Text('編集'),
        actions: [
          IconButton(
            key: const ValueKey('quote-save-button'),
            tooltip: '保存',
            onPressed: rawQuote == null || _saving ? null : _save,
            icon: _saving
                ? const Semantics(
                    label: '保存中',
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.save_outlined, semanticLabel: ''),
          ),
        ],
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.project.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (widget.revisionIntent.isRevision) ...[
            const SizedBox(height: 6),
            Text(
              '改訂理由: ${widget.revisionIntent.changeReason ?? "未入力"}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 6),
          const Text('見積書を読み取り、自動抽出された箇所だけ確認・修正して保存します。'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: 'PDFを読み込み',
                  onTap: _processing ? null : _pickPdf,
                  child: ExcludeSemantics(
                    child: FilledButton.icon(
                      key: const ValueKey('quote-pdf-button'),
                      onPressed: _processing ? null : _pickPdf,
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('PDF'),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '写真を読み込み',
                  onTap: _processing ? null : _pickPhoto,
                  child: ExcludeSemantics(
                    child: OutlinedButton.icon(
                      key: const ValueKey('quote-photo-button'),
                      onPressed: _processing ? null : _pickPhoto,
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: const Text('写真'),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_processing) ...[
            const SizedBox(height: 24),
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('文字と見積項目を読み取っています…'),
                  ],
                ),
              ),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      semanticLabel: 'エラー',
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (rawQuote != null) ...[
            const SizedBox(height: 20),
            if (reviewBundle != null)
              OcrReviewOverview(
                bundle: reviewBundle,
                statuses: _reviewStatuses,
                onStatusChanged: _setReviewStatus,
              ),
            const SizedBox(height: 16),
            Semantics(
              header: true,
              child: Text('基本情報', style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('quote-contractor-field'),
              controller: _contractorController,
              maxLength: 100,
              decoration: const InputDecoration(
                labelText: '業者名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('quote-total-field'),
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '提示総額（税込・円）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          '抽出明細 (${_editableItems.length}件)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Text(
                        'カテゴリはOCR結果から自動判定しています。必要に応じて変更してください。',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '明細を追加',
                  onPressed: _addLineItem,
                  icon: const Icon(Icons.add_circle_outline, semanticLabel: ''),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_editableItems.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text('カテゴリ明細を自動判定できませんでした。'),
                      const SizedBox(height: 8),
                      Semantics(
                        button: true,
                        label: '明細を追加',
                        onTap: _addLineItem,
                        child: ExcludeSemantics(
                          child: OutlinedButton.icon(
                            onPressed: _addLineItem,
                            icon: const Icon(Icons.add),
                            label: const Text('追加'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._editableItems.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EditableLineCard(
                    key: ValueKey(entry.value),
                    index: entry.key,
                    item: entry.value,
                    reviewStatus: entry.value.sourceLine == null
                        ? null
                        : _statusFor(entry.value.sourceLine!),
                    onReviewStatusChanged: entry.value.sourceLine == null
                        ? null
                        : (status) => _setReviewStatus(
                            entry.value.sourceLine!.id,
                            status,
                          ),
                    onRemove: () => _removeLineItem(entry.key),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('OCR抽出テキストを確認'),
              children: [
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 140,
                    maxHeight: 320,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(rawQuote.extractedText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              button: true,
              label: '見積を保存',
              onTap: _saving ? null : _save,
              child: ExcludeSemantics(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? '保存中…' : '保存'),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditableLineCard extends StatefulWidget {
  const _EditableLineCard({
    super.key,
    required this.index,
    required this.item,
    required this.onRemove,
    this.reviewStatus,
    this.onReviewStatusChanged,
  });

  final int index;
  final _EditableLineItem item;
  final VoidCallback onRemove;
  final OcrReviewStatus? reviewStatus;
  final ValueChanged<OcrReviewStatus>? onReviewStatusChanged;

  @override
  State<_EditableLineCard> createState() => _EditableLineCardState();
}

class _EditableLineCardState extends State<_EditableLineCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Semantics(
              header: true,
              child: Text(
                '明細 ${widget.index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            Semantics(
              button: true,
              label: '明細 ${widget.index + 1}を削除',
              onTap: widget.onRemove,
              child: ExcludeSemantics(
                child: IconButton(
                  tooltip: '削除',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
          ],
        ),
        TextField(
          controller: item.rawLabelController,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: '項目名・原文',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: item.categoryId,
          decoration: const InputDecoration(
            labelText: 'カテゴリ（自動判定・変更可）',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final category in CategoryMaster.categories)
              DropdownMenuItem(
                value: category.id,
                child: Text(category.nameJa),
              ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => item.categoryId = value);
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<InclusionStatus>(
          initialValue: item.inclusionStatus,
          decoration: const InputDecoration(
            labelText: '見積への含まれ方',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final status in InclusionStatus.values)
              DropdownMenuItem(value: status, child: Text(status.labelJa)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => item.inclusionStatus = value);
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: item.amountController,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          decoration: const InputDecoration(
            labelText: '金額（円・未記載は空欄）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: item.quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: item.unitController,
                decoration: const InputDecoration(
                  labelText: '単位',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: item.specificationController,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: '仕様・備考',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final line = item.sourceLine;
            final status = widget.reviewStatus;
            final onChanged = widget.onReviewStatusChanged;
            if (line == null || status == null || onChanged == null) {
              return editor;
            }
            final review = OcrLineReviewPanel(
              line: line,
              status: status,
              onChanged: onChanged,
            );
            if (constraints.maxWidth >= 680) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 220, child: review),
                  const SizedBox(width: 16),
                  Expanded(child: editor),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [review, const SizedBox(height: 12), editor],
            );
          },
        ),
      ),
    );
  }
}

class _EditableLineItem {
  _EditableLineItem({
    required this.rawLabelController,
    required this.amountController,
    required this.quantityController,
    required this.unitController,
    required this.specificationController,
    required this.categoryId,
    required this.inclusionStatus,
    this.note,
    this.sourceLine,
  });

  factory _EditableLineItem.fromModel(
    RawQuoteLineItem item, {
    OcrRecognizedLine? sourceLine,
  }) {
    return _EditableLineItem(
      rawLabelController: TextEditingController(text: item.rawLabel),
      amountController: TextEditingController(
        text: item.amountYen == null ? '' : item.amountYen.toString(),
      ),
      quantityController: TextEditingController(
        text: item.quantity == null ? '' : item.quantity.toString(),
      ),
      unitController: TextEditingController(text: item.unit ?? ''),
      specificationController: TextEditingController(
        text: item.specification ?? '',
      ),
      categoryId: CategoryMaster.find(item.categoryId) == null
          ? CategoryMaster.categories.first.id
          : item.categoryId,
      inclusionStatus: item.inclusionStatus,
      note: item.note,
      sourceLine: sourceLine,
    );
  }

  factory _EditableLineItem.empty() => _EditableLineItem(
    rawLabelController: TextEditingController(),
    amountController: TextEditingController(),
    quantityController: TextEditingController(),
    unitController: TextEditingController(),
    specificationController: TextEditingController(),
    categoryId: CategoryMaster.categories.first.id,
    inclusionStatus: InclusionStatus.unknown,
  );

  final TextEditingController rawLabelController;
  final TextEditingController amountController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController specificationController;
  String categoryId;
  InclusionStatus inclusionStatus;
  final String? note;
  final OcrRecognizedLine? sourceLine;

  RawQuoteLineItem toModel(int index) {
    final rawLabel = rawLabelController.text.trim();
    if (rawLabel.isEmpty) {
      throw FormatException('明細${index + 1}の項目名を入力してください。');
    }
    if (rawLabel.length > 300) {
      throw FormatException('明細${index + 1}の項目名は300文字以内で入力してください。');
    }

    final amountText = amountController.text.trim();
    final allowNegative = categoryId == 'discount';
    final amount = amountText.isEmpty
        ? null
        : LocalizedNumberParser.tryParseYen(
            amountText,
            allowNegative: allowNegative,
          );
    if (amountText.isNotEmpty && amount == null) {
      throw FormatException(
        allowNegative
            ? '明細${index + 1}の金額を整数で入力してください。'
            : '明細${index + 1}の金額は0以上の整数で入力してください。',
      );
    }

    final quantityText = quantityController.text.trim();
    final quantity = quantityText.isEmpty
        ? null
        : LocalizedNumberParser.tryParseDecimal(quantityText);
    if (quantityText.isNotEmpty && (quantity == null || quantity <= 0)) {
      throw FormatException('明細${index + 1}の数量は0より大きい数値で入力してください。');
    }

    final unit = UnitNormalizer.normalize(unitController.text);
    final specification = specificationController.text.trim();
    if (specification.length > 500) {
      throw FormatException('明細${index + 1}の仕様は500文字以内で入力してください。');
    }
    return RawQuoteLineItem(
      rawLabel: rawLabel,
      categoryId: categoryId,
      amountYen: amount,
      inclusionStatus: inclusionStatus,
      quantity: quantity,
      unit: unit,
      specification: specification.isEmpty ? null : specification,
      note: note,
    );
  }

  void dispose() {
    rawLabelController.dispose();
    amountController.dispose();
    quantityController.dispose();
    unitController.dispose();
    specificationController.dispose();
  }
}
