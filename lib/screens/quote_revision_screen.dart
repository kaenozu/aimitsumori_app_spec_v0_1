/// 見積書の改訂履歴、差分、比較対象選択を表示する画面。
library;

import '../utils/app_logger.dart';

import '../utils/formatting.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/category_master.dart';
import '../models.dart';
import '../quote_revision_models.dart';
import '../repositories/project_repository.dart';
import '../repositories/quote_revision_repository.dart';
import '../services/quote_revision_diff_engine.dart';
import '../services/quote_revision_import_coordinator.dart';
import 'quote_input_screen.dart';
import 'revision_comparison_screen.dart';

class QuoteRevisionScreen extends StatefulWidget {
  const QuoteRevisionScreen({
    super.key,
    required this.project,
    this.repository,
    this.projectRepository,
  });

  final Project project;
  final QuoteRevisionRepository? repository;
  final ProjectRepository? projectRepository;

  @override
  State<QuoteRevisionScreen> createState() => _QuoteRevisionScreenState();
}

class _QuoteRevisionScreenState extends State<QuoteRevisionScreen> {
  late final QuoteRevisionRepository _repository =
      widget.repository ?? QuoteRevisionRepository.instance;
  final QuoteRevisionDiffEngine _diffEngine = const QuoteRevisionDiffEngine();
  final QuoteRevisionImportCoordinator _importCoordinator =
      QuoteRevisionImportCoordinator();
  final Map<String, String> _selectedRevisionIds = {};

  List<QuoteRevision> _revisions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await _repository.ensureInitialRevisions(widget.project);
      final revisions = await _repository.getProjectRevisions(
        widget.project.id,
      );
      final groups = _groups(revisions);
      for (final entry in groups.entries) {
        final ordered = [...entry.value]
          ..sort(
            (left, right) =>
                left.revisionNumber.compareTo(right.revisionNumber),
          );
        _selectedRevisionIds.putIfAbsent(entry.key, () => ordered.last.id);
      }
      _selectedRevisionIds.removeWhere(
        (groupId, _) => !groups.containsKey(groupId),
      );
      if (!mounted) return;
      setState(() {
        _revisions = revisions;
        _loading = false;
        _error = null;
      });
    } catch (error, stackTrace) {
      AppLogger.debug('Quote revision load failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = '改訂履歴を読み込めませんでした。';
        _loading = false;
      });
    }
  }

  Map<String, List<QuoteRevision>> _groups(List<QuoteRevision> revisions) {
    final groups = <String, List<QuoteRevision>>{};
    for (final revision in revisions) {
      groups.putIfAbsent(revision.quoteGroupId, () => []).add(revision);
    }
    return groups;
  }

  List<QuoteRevision> get _selectedRevisions {
    final byId = {for (final revision in _revisions) revision.id: revision};
    return _selectedRevisionIds.values
        .map((id) => byId[id])
        .whereType<QuoteRevision>()
        .toList(growable: false);
  }

  Future<void> _compareSelected() async {
    final selected = _selectedRevisions;
    if (selected.isEmpty) {
      _showMessage('比較する改訂版を選択してください。');
      return;
    }
    final comparisonProject = widget.project.copyWith(
      quotes: [for (final revision in selected) revision.quoteSnapshot],
      updatedAtEpochMillis: widget.project.updatedAtEpochMillis,
    );
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => RevisionComparisonScreen(project: comparisonProject),
      ),
    );
  }

  Future<void> _registerNewContractor() =>
      _openQuoteInput(_importCoordinator.newQuote());

  Future<void> _registerExistingRevision() async {
    if (_revisions.isEmpty) return;
    final parent = await showModalBottomSheet<QuoteRevision>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('改訂元の見積を選択'),
              subtitle: Text('任意の過去版を親にして新しい改訂版を作成します。'),
            ),
            for (final revision in _revisions.reversed)
              ListTile(
                leading: CircleAvatar(
                  child: Text('${revision.revisionNumber}'),
                ),
                title: Text(
                  '${revision.contractorName} 第${revision.revisionNumber}版',
                ),
                subtitle: Text(
                  '${formatDate(revision.importedAt)} / '
                  '総額 ${formatYen(revision.quoteSnapshot.totalAmountYen)}',
                ),
                onTap: () => Navigator.pop(context, revision),
              ),
          ],
        ),
      ),
    );
    if (parent == null || !mounted) return;
    await _createRevisionFrom(parent);
  }

  Future<void> _createRevisionFrom(QuoteRevision parent) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${parent.contractorName} 第${parent.revisionNumber}版から改訂'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '変更理由（例：仕様変更、値引き反映）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.pop(context, value.isEmpty ? '過去版を基に改訂' : value);
            },
            child: const Text('見積書を取り込む'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (reason == null || !mounted) return;

    final intent = _importCoordinator.revisionFromHistory(
      parentRevision: parent,
      changeReason: reason,
    );
    await _openQuoteInput(intent);
  }

  Future<void> _openQuoteInput(QuoteImportIntent intent) async {
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteInputScreen(
            project: widget.project,
            repository: widget.projectRepository,
            revisionIntent: intent,
          ),
        ),
      );
      if (saved == true) await _load();
    } catch (error, stackTrace) {
      AppLogger.debug('Quote revision import failed: $error\n$stackTrace');
      if (mounted) {
        _showMessage('見積書の取り込み画面を開けませんでした。');
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups(_revisions);
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: '改訂履歴画面',
          child: const Text('改訂履歴'),
        ),
        actions: [
          Semantics(
            button: true,
            enabled: !_loading,
            label: '選択した改訂版を比較',
            child: IconButton(
              tooltip: '選択した改訂版を比較',
              onPressed: _loading ? null : _compareSelected,
              icon: const Icon(Icons.compare_arrows_outlined),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    widget.project.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text('同一業者の見積を版として管理し、業者ごとに任意の版を比較対象へ選べます。'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _registerNewContractor,
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: const Text('新規業者として登録'),
                      ),
                      FilledButton.icon(
                        onPressed: _revisions.isEmpty
                            ? null
                            : _registerExistingRevision,
                        icon: const Icon(Icons.history_outlined),
                        label: const Text('既存見積の改訂版として登録'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: groups.isEmpty ? null : _compareSelected,
                    icon: const Icon(Icons.compare_arrows_outlined),
                    label: Text('選択した${_selectedRevisions.length}件を比較'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.history_outlined),
                        title: Text('改訂履歴はまだありません'),
                        subtitle: Text('新規見積を登録すると第1版が保存されます。'),
                      ),
                    ),
                  for (final entry in groups.entries)
                    _RevisionGroupCard(
                      revisions: entry.value,
                      selectedRevisionId: _selectedRevisionIds[entry.key],
                      diffEngine: _diffEngine,
                      onSelected: (revisionId) {
                        setState(() {
                          _selectedRevisionIds[entry.key] = revisionId;
                        });
                      },
                      onCreateRevision: _createRevisionFrom,
                    ),
                ],
              ),
            ),
    );
  }
}

class _RevisionGroupCard extends StatelessWidget {
  const _RevisionGroupCard({
    required this.revisions,
    required this.selectedRevisionId,
    required this.diffEngine,
    required this.onSelected,
    required this.onCreateRevision,
  });

  final List<QuoteRevision> revisions;
  final String? selectedRevisionId;
  final QuoteRevisionDiffEngine diffEngine;
  final ValueChanged<String> onSelected;
  final ValueChanged<QuoteRevision> onCreateRevision;

  @override
  Widget build(BuildContext context) {
    final ordered = [...revisions]
      ..sort(
        (left, right) => left.revisionNumber.compareTo(right.revisionNumber),
      );
    final byId = {for (final revision in ordered) revision.id: revision};
    final latest = ordered.last;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.history_outlined),
        title: Text(latest.contractorName),
        subtitle: Text(
          '最新: 第${latest.revisionNumber}版 / ${_date(latest.importedAt)}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          for (var index = 0; index < ordered.length; index++) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                selectedRevisionId == ordered[index].id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text('第${ordered[index].revisionNumber}版'),
              subtitle: Text(
                [
                  _date(ordered[index].importedAt),
                  if (ordered[index].changeReason?.isNotEmpty == true)
                    ordered[index].changeReason!,
                  if (ordered[index].parentRevisionId != null)
                    '親版: 第${byId[ordered[index].parentRevisionId]?.revisionNumber ?? '-'}版',
                  '総額: ${formatYen(ordered[index].quoteSnapshot.totalAmountYen)}',
                ].join(' / '),
              ),
              trailing: IconButton(
                tooltip: 'この版から新しい改訂版を作成',
                onPressed: () => onCreateRevision(ordered[index]),
                icon: const Icon(Icons.note_add_outlined),
              ),
              onTap: () => onSelected(ordered[index].id),
            ),
            if (_parentFor(ordered, byId, index) case final parent?)
              _DiffView(diff: diffEngine.compare(parent, ordered[index])),
            if (index < ordered.length - 1) const Divider(),
          ],
        ],
      ),
    );
  }

  QuoteRevision? _parentFor(
    List<QuoteRevision> ordered,
    Map<String, QuoteRevision> byId,
    int index,
  ) {
    final explicitParent = byId[ordered[index].parentRevisionId];
    if (explicitParent != null) return explicitParent;
    return index == 0 ? null : ordered[index - 1];
  }
}

class _DiffView extends StatelessWidget {
  const _DiffView({required this.diff});

  final QuoteRevisionDiff diff;

  @override
  Widget build(BuildContext context) {
    final total = diff.totalDifferenceYen;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第${diff.before.revisionNumber}版 → '
            '第${diff.after.revisionNumber}版',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            total == null
                ? '総額差: 比較不可'
                : '総額差: ${total >= 0 ? '+' : ''}'
                      '${NumberFormat('#,##0', 'ja_JP').format(total)}円',
          ),
          if (diff.changes.isEmpty)
            const Text('明細変更なし')
          else
            for (final change in diff.changes)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_icon(change.type)),
                title: Text(
                  CategoryMaster.find(change.categoryId)?.nameJa ??
                      change.label,
                ),
                subtitle: Text(_description(change)),
              ),
        ],
      ),
    );
  }

  static IconData _icon(QuoteLineChangeType type) => switch (type) {
    QuoteLineChangeType.added => Icons.add_circle_outline,
    QuoteLineChangeType.removed => Icons.remove_circle_outline,
    QuoteLineChangeType.amount => Icons.currency_yen,
    QuoteLineChangeType.unitPrice => Icons.price_change_outlined,
    QuoteLineChangeType.quantity => Icons.straighten,
    QuoteLineChangeType.unit => Icons.square_foot,
    QuoteLineChangeType.specification => Icons.description_outlined,
    QuoteLineChangeType.inclusion => Icons.rule_outlined,
  };

  static String _description(QuoteLineChange change) => switch (change.type) {
    QuoteLineChangeType.added => '明細を追加: ${change.after?.rawLabel ?? ''}',
    QuoteLineChangeType.removed => '明細を削除: ${change.before?.rawLabel ?? ''}',
    QuoteLineChangeType.amount =>
      '金額: ${change.before?.amountYen ?? '未入力'} → '
          '${change.after?.amountYen ?? '未入力'}',
    QuoteLineChangeType.unitPrice =>
      '単価: ${_unitPrice(change.beforeUnitPriceYen)} → '
          '${_unitPrice(change.afterUnitPriceYen)}',
    QuoteLineChangeType.quantity =>
      '数量: ${change.before?.quantity ?? '未入力'} → '
          '${change.after?.quantity ?? '未入力'}',
    QuoteLineChangeType.unit =>
      '単位: ${change.before?.unit ?? '未入力'} → '
          '${change.after?.unit ?? '未入力'}',
    QuoteLineChangeType.specification =>
      '仕様: ${change.before?.specification ?? '未入力'} → '
          '${change.after?.specification ?? '未入力'}',
    QuoteLineChangeType.inclusion =>
      '状態: ${change.before?.inclusionStatus.labelJa ?? '未入力'} → '
          '${change.after?.inclusionStatus.labelJa ?? '未入力'}',
  };

  static String _unitPrice(double? value) => value == null
      ? '算出不可'
      : '${NumberFormat('#,##0.##', 'ja_JP').format(value)}円';
}

String _date(int epoch) => DateFormat(
  'yyyy/MM/dd HH:mm',
).format(DateTime.fromMillisecondsSinceEpoch(epoch));
