/// 案件の18カテゴリを必須・任意・不要・未設定に分類する画面。
library;

import 'package:flutter/material.dart';

import '../data/category_master.dart';
import '../models.dart';
import '../repositories/project_requirement_repository.dart';
import '../requirements_models.dart';

class RequirementsChecklistScreen extends StatefulWidget {
  const RequirementsChecklistScreen({
    super.key,
    required this.project,
    this.repository,
    this.creationFlow = false,
  });

  final Project project;
  final ProjectRequirementRepository? repository;
  final bool creationFlow;

  @override
  State<RequirementsChecklistScreen> createState() =>
      _RequirementsChecklistScreenState();
}

class _RequirementsChecklistScreenState
    extends State<RequirementsChecklistScreen> {
  ProjectRequirementRepository get _repository =>
      widget.repository ?? ProjectRequirementRepository.instance;

  List<_RequirementEditor> _editors = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final editor in _editors) {
      editor.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final requirements = await _repository.getRequirements(widget.project.id);
      if (!mounted) return;
      for (final editor in _editors) {
        editor.dispose();
      }
      setState(() {
        _editors = requirements.map(_RequirementEditor.new).toList();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    try {
      final requirements = [for (final editor in _editors) editor.toModel()];
      setState(() {
        _saving = true;
        _error = null;
      });
      await _repository.saveRequirements(widget.project.id, requirements);
      if (!mounted) return;
      if (widget.creationFlow) {
        Navigator.pop(context, true);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('要望・工事範囲を保存しました。')));
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int get _configuredCount => _editors
      .where((editor) => editor.priority != RequirementPriority.unset)
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.creationFlow ? '案件の要望を設定' : '要望・工事範囲')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  widget.project.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  widget.creationFlow
                      ? '要望は後からでも入力できます。まず見積を追加して比較を始められます。'
                      : '必要な項目だけ、必須・任意・不要に設定します。',
                ),
                const SizedBox(height: 8),
                Text(
                  '設定済み $_configuredCount / ${CategoryMaster.categories.length}',
                ),
                if (widget.creationFlow) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    key: const ValueKey('skip-requirements-button'),
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, true),
                    icon: const Icon(Icons.document_scanner_outlined),
                    label: const Text('要望は後で、見積を追加する'),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!)),
                          IconButton(
                            tooltip: '再読み込み',
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                for (var index = 0; index < _editors.length; index++) ...[
                  _RequirementCard(
                    key: ValueKey(
                      'requirement-${_editors[index].requirement.categoryId}',
                    ),
                    editor: _editors[index],
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('save-requirements-button'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(widget.creationFlow ? '保存して案件を開く' : '保存'),
                ),
                if (widget.creationFlow) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('要望は後で設定する'),
                  ),
                ],
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({
    super.key,
    required this.editor,
    required this.onChanged,
  });

  final _RequirementEditor editor;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final category = CategoryMaster.require(editor.requirement.categoryId);
    final needsDetails =
        editor.priority == RequirementPriority.required ||
        editor.priority == RequirementPriority.optional;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${category.displayOrder}. ${category.nameJa}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final priority in RequirementPriority.values)
                  ChoiceChip(
                    key: ValueKey('${category.id}-${priority.code}'),
                    label: Text(priority.labelJa),
                    selected: editor.priority == priority,
                    onSelected: (_) {
                      editor.priority = priority;
                      onChanged();
                    },
                  ),
              ],
            ),
            if (needsDetails) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: editor.quantityController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '希望数量',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: editor.unitController,
                      decoration: const InputDecoration(
                        labelText: '単位',
                        hintText: 'm、㎡、台など',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: editor.specificationController,
                decoration: const InputDecoration(
                  labelText: '希望仕様',
                  hintText: '製品名・型番・厚み・施工方法など',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: editor.noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'メモ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequirementEditor {
  _RequirementEditor(this.requirement)
    : priority = requirement.priority,
      quantityController = TextEditingController(
        text: requirement.expectedQuantity?.toString() ?? '',
      ),
      unitController = TextEditingController(
        text: requirement.expectedUnit ?? '',
      ),
      specificationController = TextEditingController(
        text: requirement.desiredSpecification ?? '',
      ),
      noteController = TextEditingController(text: requirement.note ?? '');

  final ProjectRequirement requirement;
  RequirementPriority priority;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController specificationController;
  final TextEditingController noteController;

  ProjectRequirement toModel() {
    final rawQuantity = quantityController.text.trim().replaceAll(',', '.');
    final quantity = rawQuantity.isEmpty ? null : double.tryParse(rawQuantity);
    if (rawQuantity.isNotEmpty && quantity == null) {
      throw FormatException(
        '${CategoryMaster.require(requirement.categoryId).nameJa}の希望数量は数値で入力してください。',
      );
    }
    return ProjectRequirement(
      categoryId: requirement.categoryId,
      priority: priority,
      expectedQuantity: quantity,
      expectedUnit: _nullable(unitController.text),
      desiredSpecification: _nullable(specificationController.text),
      note: _nullable(noteController.text),
    );
  }

  String? _nullable(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    specificationController.dispose();
    noteController.dispose();
  }
}
