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
  });

  final Project project;
  final ProjectRepository? repository;

  @override
  State<QuoteInputScreen> createState() => _QuoteInputScreenState();
}

class _QuoteInputScreenState extends State<QuoteInputScreen> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _contractorController = TextEditingController();
  final TextEditingController _totalController = TextEditingController();

  RawQuoteData? _rawQuote;
  bool _processing = false;
  bool _saving = false;
  String? _error;

  ProjectRepository get _repository => widget.repository ?? ProjectRepository.instance;

  @override
  void dispose() {
    _contractorController.dispose();
    _totalController.dispose();
    unawaited(_ocrService.dispose());
    super.dispose();
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path != null) await _process(path);
  }

  Future<void> _pickPhoto() async {
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
  }

  Future<void> _process(String path) async {
    setState(() {
      _processing = true;
      _error = null;
      _rawQuote = null;
    });

    try {
      final result = await _ocrService.extractQuote(path);
      if (!mounted) return;
      _contractorController.text = result.contractorName;
      _totalController.text = result.totalAmountYen == null
          ? ''
          : NumberFormat('#,##0', 'ja_JP').format(result.totalAmountYen);
      setState(() => _rawQuote = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _save() async {
    final rawQuote = _rawQuote;
    if (rawQuote == null || _saving) return;

    final contractorName = _contractorController.text.trim();
    if (contractorName.isEmpty) {
      setState(() => _error = '業者名を入力してください。');
      return;
    }

    final normalizedTotal = _totalController.text.replaceAll(RegExp(r'[^0-9-]'), '');
    final totalAmount = normalizedTotal.isEmpty ? null : int.tryParse(normalizedTotal);
    if (normalizedTotal.isNotEmpty && totalAmount == null) {
      setState(() => _error = '合計金額を数値で入力してください。');
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
        lineItems: rawQuote.lineItems,
        extractedText: rawQuote.extractedText,
        sourcePath: rawQuote.sourcePath,
        createdAtEpochMillis: rawQuote.createdAtEpochMillis,
      );
      await _repository.saveQuote(widget.project.id, corrected.toContractorQuote());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '保存に失敗しました: $error');
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
        padding: const EdgeInsets.all(16),
        children: [
          Text(widget.project.name, style: Theme.of(context).textTheme.titleMedium),
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
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('文字を読み取っています…')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (rawQuote != null) ...[
            const SizedBox(height: 20),
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
            Text(
              '抽出明細 (${rawQuote.lineItems.length}件)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (rawQuote.lineItems.isEmpty)
              const Text('カテゴリ明細を自動判定できませんでした。保存後に手動確認してください。')
            else
              ...rawQuote.lineItems.map(
                (item) => Card(
                  child: ListTile(
                    title: Text(CategoryMaster.find(item.categoryId)?.nameJa ?? item.categoryId),
                    subtitle: Text(item.rawLabel),
                    trailing: Text(
                      item.amountYen == null
                          ? item.inclusionStatus.labelJa
                          : '${NumberFormat('#,##0', 'ja_JP').format(item.amountYen)}円',
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Text('OCR抽出テキスト', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(minHeight: 180, maxHeight: 360),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SingleChildScrollView(
                child: SelectableText(rawQuote.extractedText),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ],
      ),
    );
  }
}
