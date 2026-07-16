/// ファイルパス: lib/screens/quote_input_screen.dart
/// PDF・カメラ・写真から見積を取り込み、OCR結果を確認して保存する画面
library;

import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/category_master.dart';
import '../models.dart';
import '../repositories/project_repository.dart';
import '../services/ocr_service.dart';

class QuoteInputScreen extends StatefulWidget {
  const QuoteInputScreen({
    super.key,
    required this.project,
    this.repository,
    this.ocrService,
  });

  final Project project;
  final ProjectRepository? repository;
  final OcrService? ocrService;

  @override
  State<QuoteInputScreen> createState() => _QuoteInputScreenState();
}

class _QuoteInputScreenState extends State<QuoteInputScreen> {
  late final OcrService _ocrService = widget.ocrService ?? OcrService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _contractorController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  RawQuoteData? _rawQuote;
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
    unawaited(_ocrService.dispose());
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
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
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
      setState(
        () => _error = '写真を開けませんでした。カメラ・写真へのアクセス権限を確認してください。',
      );
    }
  }

  Future<void> _process(String path) async {
    setState(() {
      _processing = true;
      _error = null;
      _rawQuote = null;
      _replaceEditableItems(const []);
    });

    try {
      final result = await _ocrService.extractQuote(path);
      if (!mounted) return;
      _contractorController.text = result.contractorName;
      _totalController.text = result.totalAmountYen == null
          ? ''
          : NumberFormat('#,##0', 'ja_JP').format(result.totalAmountYen);
      setState(() {
        _rawQuote = result;
        _replaceEditableItems(result.lineItems);
      });
    } on OcrException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error, stackTrace) {
      debugPrint('OCR processing failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(
        () => _error = '文字の読み取りに失敗しました。画像の明るさ・向き・解像度を確認して、もう一度お試しください。',
      );
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _replaceEditableItems(List<RawQuoteLineItem> items) {
    for (final item in _editableItems) {
      item.dispose();
    }
    _editableItems = items.map(_EditableLineItem.fromModel).toList();
  }

  void _addLineItem() {
    setState(() {
      _editableItems.add(_EditableLineItem.empty());
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      final removed = _editableItems.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _save() async {
    final rawQuote = _rawQuote;
    if (rawQuote == null || _saving) return;

    final contractorName = _contractorController.text.trim();
    if (contractorName.isEmpty) {
      setState(() => _error = '業者名を入力してください。');
      return;
    }

    final normalizedTotal =
        _totalController.text.replaceAll(RegExp(r'[^0-9-]'), '');
    final totalAmount =
        normalizedTotal.isEmpty ? null : int.tryParse(normalizedTotal);
    if (normalizedTotal.isNotEmpty && totalAmount == null) {
      setState(() => _error = '合計金額を数値で入力してください。');
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
      await _repository.saveQuote(
        widget.project.id,
        corrected.toContractorQuote(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('見積を保存しました。')),
      );
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('見積書を取り込む')),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.project.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text('見積書を読み取り、自動抽出された箇所だけ確認・修正して保存します。'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _processing ? null : _pickPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDFを読み込み'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _processing ? null : _pickPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('写真を読み込み'),
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
            Text(
              '基本情報',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
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
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '抽出明細 (${_editableItems.length}件)',
                        style: Theme.of(context).textTheme.titleMedium,
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
                  icon: const Icon(Icons.add_circle_outline),
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
                      OutlinedButton.icon(
                        onPressed: _addLineItem,
                        icon: const Icon(Icons.add),
                        label: const Text('明細を手動追加'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: 520,
                child: ListView.separated(
                  itemCount: _editableItems.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _EditableLineCard(
                    key: ValueKey(_editableItems[index]),
                    index: index,
                    item: _editableItems[index],
                    onRemove: () => _removeLineItem(index),
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
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '確認して保存'),
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
  });

  final int index;
  final _EditableLineItem item;
  final VoidCallback onRemove;

  @override
  State<_EditableLineCard> createState() => _EditableLineCardState();
}

class _EditableLineCardState extends State<_EditableLineCard> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '明細 ${widget.index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: '明細を削除',
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            TextField(
              controller: item.rawLabelController,
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
                  DropdownMenuItem(
                    value: status,
                    child: Text(status.labelJa),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => item.inclusionStatus = value);
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: item.amountController,
              keyboardType: TextInputType.number,
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
              decoration: const InputDecoration(
                labelText: '仕様・備考',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
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
  });

  factory _EditableLineItem.fromModel(RawQuoteLineItem item) {
    return _EditableLineItem(
      rawLabelController: TextEditingController(text: item.rawLabel),
      amountController: TextEditingController(
        text: item.amountYen == null ? '' : item.amountYen.toString(),
      ),
      quantityController: TextEditingController(
        text: item.quantity == null ? '' : item.quantity.toString(),
      ),
      unitController: TextEditingController(text: item.unit ?? ''),
      specificationController:
          TextEditingController(text: item.specification ?? ''),
      categoryId: CategoryMaster.find(item.categoryId) == null
          ? CategoryMaster.categories.first.id
          : item.categoryId,
      inclusionStatus: item.inclusionStatus,
      note: item.note,
    );
  }

  factory _EditableLineItem.empty() {
    return _EditableLineItem(
      rawLabelController: TextEditingController(),
      amountController: TextEditingController(),
      quantityController: TextEditingController(),
      unitController: TextEditingController(),
      specificationController: TextEditingController(),
      categoryId: CategoryMaster.categories.first.id,
      inclusionStatus: InclusionStatus.unknown,
    );
  }

  final TextEditingController rawLabelController;
  final TextEditingController amountController;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController specificationController;
  String categoryId;
  InclusionStatus inclusionStatus;
  final String? note;

  RawQuoteLineItem toModel(int index) {
    final rawLabel = rawLabelController.text.trim();
    if (rawLabel.isEmpty) {
      throw FormatException('明細${index + 1}の項目名を入力してください。');
    }

    final normalizedAmount =
        amountController.text.replaceAll(RegExp(r'[^0-9-]'), '');
    final amount =
        normalizedAmount.isEmpty ? null : int.tryParse(normalizedAmount);
    if (normalizedAmount.isNotEmpty && amount == null) {
      throw FormatException('明細${index + 1}の金額を数値で入力してください。');
    }

    final normalizedQuantity = quantityController.text
        .trim()
        .replaceAll(',', '.');
    final quantity = normalizedQuantity.isEmpty
        ? null
        : double.tryParse(normalizedQuantity);
    if (normalizedQuantity.isNotEmpty && quantity == null) {
      throw FormatException('明細${index + 1}の数量を数値で入力してください。');
    }

    final unit = unitController.text.trim();
    final specification = specificationController.text.trim();
    return RawQuoteLineItem(
      rawLabel: rawLabel,
      categoryId: categoryId,
      amountYen: amount,
      inclusionStatus: inclusionStatus,
      quantity: quantity,
      unit: unit.isEmpty ? null : unit,
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
