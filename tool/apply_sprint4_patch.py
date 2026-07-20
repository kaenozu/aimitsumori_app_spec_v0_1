from __future__ import annotations

from pathlib import Path


PATH = Path('lib/screens/quote_input_screen.dart')


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f'{label}: expected one match, found {count}')
    return text.replace(old, new, 1)


def main() -> None:
    text = PATH.read_text(encoding='utf-8')

    text = replace_once(
        text,
        "import '../repositories/project_repository.dart';\nimport '../services/ocr_review_store.dart';",
        "import '../repositories/project_repository.dart';\nimport '../services/ocr_review_store.dart';\nimport '../validation/input_validators.dart';",
        'validator import',
    )
    text = replace_once(
        text,
        "    this.ocrService,\n    this.reviewStore,\n  });",
        "    this.ocrService,\n    this.reviewStore,\n    this.initialQuote,\n  });",
        'constructor argument',
    )
    text = replace_once(
        text,
        "  final OcrService? ocrService;\n  final OcrReviewStore? reviewStore;",
        "  final OcrService? ocrService;\n  final OcrReviewStore? reviewStore;\n  final RawQuoteData? initialQuote;",
        'initial quote field',
    )
    text = replace_once(
        text,
        "  final ImagePicker _imagePicker = ImagePicker();\n  final TextEditingController _contractorController = TextEditingController();",
        "  final ImagePicker _imagePicker = ImagePicker();\n  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();\n  final TextEditingController _contractorController = TextEditingController();",
        'form key',
    )
    text = replace_once(
        text,
        "  @override\n  void dispose() {",
        """  @override
  void initState() {
    super.initState();
    final initialQuote = widget.initialQuote;
    if (initialQuote == null) return;

    _rawQuote = initialQuote;
    _contractorController.text = initialQuote.contractorName;
    _totalController.text = initialQuote.totalAmountYen == null
        ? ''
        : NumberFormat('#,##0', 'ja_JP').format(initialQuote.totalAmountYen);
    _replaceEditableItems(initialQuote.lineItems, const []);
  }

  @override
  void dispose() {""",
        'initial quote setup',
    )

    save_start = text.index('  Future<void> _save() async {')
    save_end = text.index('\n  @override\n  Widget build(BuildContext context) {', save_start)
    new_save = """  Future<void> _save() async {
    final rawQuote = _rawQuote;
    if (rawQuote == null || _saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _confirmSaveWithCriticalItems()) return;

    final contractorName = _contractorController.text.trim();
    final normalizedTotal = _totalController.text.trim().replaceAll(',', '');
    final totalAmount = int.parse(normalizedTotal);

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
      final quote = corrected.toContractorQuote(id: _pendingQuoteId);
      _pendingQuoteId ??= quote.id;
      await _repository.saveQuote(widget.project.id, quote);
      await _reviewStore.save(rawQuote.sourcePath, _reviewStatuses);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('見積を保存しました。')));
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } catch (error, stackTrace) {
      debugPrint('Quote save failed: $error\\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = '見積の保存に失敗しました。保存先を確認して、もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
"""
    text = text[:save_start] + new_save + text[save_end:]

    text = replace_once(
        text,
        '      body: ListView(',
        """      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(""",
        'form opening',
    )
    text = replace_once(
        text,
        """        ],
      ),
    );
  }
}

class _EditableLineCard""",
        """          ],
        ),
      ),
    );
  }
}

class _EditableLineCard""",
        'form closing',
    )

    text = replace_once(
        text,
        """            TextField(
              controller: _contractorController,
              decoration: const InputDecoration(
                labelText: '業者名',
                border: OutlineInputBorder(),
              ),
            ),""",
        """            TextFormField(
              key: const ValueKey('quote-contractor-field'),
              controller: _contractorController,
              decoration: const InputDecoration(
                labelText: '業者名',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? '業者名を入力してください。'
                  : null,
            ),""",
        'contractor field',
    )
    text = replace_once(
        text,
        """            TextField(
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '提示総額（税込・円）',
                border: OutlineInputBorder(),
              ),
            ),""",
        """            TextFormField(
              key: const ValueKey('quote-total-field'),
              controller: _totalController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '提示総額（税込・円）',
                border: OutlineInputBorder(),
              ),
              validator: (value) => validateAmount(
                value,
                maxDecimalPlaces: 0,
              ),
            ),""",
        'total field',
    )
    text = replace_once(
        text,
        """        TextField(
          controller: item.rawLabelController,
          decoration: const InputDecoration(
            labelText: '項目名・原文',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),""",
        """        TextFormField(
          key: ValueKey('quote-line-label-${widget.index}'),
          controller: item.rawLabelController,
          decoration: const InputDecoration(
            labelText: '項目名・原文',
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
          validator: (value) => value == null || value.trim().isEmpty
              ? '項目名を入力してください。'
              : null,
        ),""",
        'line label field',
    )
    text = replace_once(
        text,
        """        TextField(
          controller: item.amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '金額（円・未記載は空欄）',
            border: OutlineInputBorder(),
          ),
        ),""",
        """        TextFormField(
          key: ValueKey('quote-line-amount-${widget.index}'),
          controller: item.amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '金額（円・未記載は空欄）',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) return null;
            return validateAmount(value, maxDecimalPlaces: 0);
          },
        ),""",
        'line amount field',
    )
    text = replace_once(
        text,
        """              child: TextField(
                controller: item.quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
              ),""",
        """              child: TextFormField(
                key: ValueKey('quote-line-quantity-${widget.index}'),
                controller: item.quantityController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '数量',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  return validateQuantity(value);
                },
              ),""",
        'line quantity field',
    )

    model_start = text.index('  RawQuoteLineItem toModel(int index) {')
    model_end = text.index('\n  void dispose() {', model_start)
    new_model = """  RawQuoteLineItem toModel(int index) {
    final rawLabel = rawLabelController.text.trim();
    if (rawLabel.isEmpty) {
      throw FormatException('明細${index + 1}の項目名を入力してください。');
    }

    final normalizedAmount = amountController.text.trim().replaceAll(',', '');
    final amount = normalizedAmount.isEmpty ? null : int.tryParse(normalizedAmount);
    if (normalizedAmount.isNotEmpty && amount == null) {
      throw FormatException('明細${index + 1}の金額を数値で入力してください。');
    }

    final normalizedQuantity = quantityController.text.trim().replaceAll(',', '');
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
"""
    text = text[:model_start] + new_model + text[model_end:]

    PATH.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    main()
