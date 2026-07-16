/// ファイルパス: lib/screens/comparison_screen.dart
/// 比較画面 - 更新、共有、カテゴリ比較、質問テンプレート、広告
library;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../comparison_engine.dart';
import '../models.dart';
import '../normalizer.dart';
import '../question_generator.dart';
import '../repositories/project_repository.dart';
import '../services/ad_service.dart';
import '../services/comparison_export_service.dart';
import 'quote_input_screen.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({
    super.key,
    required this.project,
    this.repository,
    this.adService,
  });

  final Project project;
  final ProjectRepository? repository;
  final AdService? adService;

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  late Project _project;
  late ComparisonReport _report;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  bool _detailsUnlocked = false;
  bool _unlocking = false;

  ProjectRepository get _repository =>
      widget.repository ?? ProjectRepository.instance;
  AdService get _adService => widget.adService ?? AdService.instance;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _report = _generateReport();
    _detailsUnlocked = _adService.adFree.value;
    _adService.adFree.addListener(_onAdFreeChanged);
    _loadBanner();
    _saveReport();
  }

  @override
  void dispose() {
    _adService.adFree.removeListener(_onAdFreeChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  ComparisonReport _generateReport() {
    final normalized = Normalizer().normalize(_project);
    final questions = QuestionGenerator().generate(
      project: _project,
      normalizedQuotes: normalized,
    );
    return ComparisonEngine().compare(
      project: _project,
      normalizedQuotes: normalized,
      questions: questions,
    );
  }

  Future<void> _saveReport({bool notifyOnError = false}) async {
    try {
      await _repository.saveComparisonResult(_report);
    } catch (error, stackTrace) {
      debugPrint('Comparison result save failed: $error\n$stackTrace');
      if (notifyOnError && mounted) {
        _showMessage(error.toString());
      }
    }
  }

  void _onAdFreeChanged() {
    if (!mounted) return;
    if (_adService.adFree.value) {
      _bannerAd?.dispose();
      _bannerAd = null;
      setState(() {
        _bannerLoaded = false;
        _detailsUnlocked = true;
      });
    } else {
      _loadBanner();
    }
  }

  void _loadBanner() {
    if (_adService.adFree.value || _bannerAd != null) return;
    try {
      final ad = _adService.createBannerAd(
        onLoaded: () {
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onFailed: (error) {
          debugPrint('Banner ad failed to load: $error');
          _bannerAd = null;
          if (mounted) setState(() => _bannerLoaded = false);
        },
      );
      _bannerAd = ad;
      ad?.load();
    } catch (error, stackTrace) {
      debugPrint('Banner ad request failed: $error\n$stackTrace');
      _bannerAd = null;
      if (mounted) setState(() => _bannerLoaded = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final refreshed = await _repository.getProject(_project.id);
      if (refreshed == null) {
        throw const ProjectRepositoryException(
          '案件の再読み込み',
          'project not found',
        );
      }
      if (!mounted) return;
      setState(() {
        _project = refreshed;
        _report = _generateReport();
        if (_adService.adFree.value) _detailsUnlocked = true;
      });
      await _saveReport(notifyOnError: true);
    } catch (error, stackTrace) {
      debugPrint('Comparison refresh failed: $error\n$stackTrace');
      if (mounted) _showMessage(error.toString());
    }
  }

  Future<void> _addQuote() async {
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => QuoteInputScreen(
            project: _project,
            repository: _repository,
          ),
        ),
      );
      if (saved == true) await _refresh();
    } catch (error, stackTrace) {
      debugPrint('Quote input navigation failed: $error\n$stackTrace');
      if (mounted) _showMessage('見積の追加画面を開けませんでした。もう一度お試しください。');
    }
  }

  Future<void> _unlockDetails() async {
    if (_detailsUnlocked || _unlocking) return;
    setState(() => _unlocking = true);

    RewardedAdOutcome outcome;
    try {
      outcome = await _adService.showRewardedAd();
    } catch (error) {
      debugPrint('Rewarded ad flow failed: $error');
      outcome = RewardedAdOutcome.unavailable;
    }
    if (!mounted) return;

    final unlocked = outcome != RewardedAdOutcome.dismissed;
    setState(() {
      _unlocking = false;
      _detailsUnlocked = unlocked;
    });

    if (outcome == RewardedAdOutcome.unavailable) {
      _showMessage('広告を読み込めなかったため、詳細比較をそのまま表示します。');
    } else if (!unlocked) {
      _showMessage('広告を最後まで視聴すると詳細比較を表示できます。');
    }
  }

  Future<void> _purchaseRemoveAds() async {
    final started = await _adService.purchaseRemoveAds();
    if (mounted && !started) {
      _showMessage('購入商品を取得できませんでした。通信状態とストア設定を確認してください。');
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await _adService.restorePurchases();
      if (mounted) _showMessage('購入履歴の復元を開始しました。');
    } catch (error) {
      debugPrint('Purchase restore failed: $error');
      if (mounted) _showMessage('購入履歴を復元できませんでした。通信状態を確認してください。');
    }
  }

  Future<void> _shareComparison(BuildContext shareContext) async {
    try {
      final renderObject = shareContext.findRenderObject();
      final origin = renderObject is RenderBox
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      await SharePlus.instance.share(
        ShareParams(
          text: ComparisonExportService.toText(_report),
          subject: '${_report.projectName} 相見積もり比較',
          title: '比較結果を共有',
          sharePositionOrigin: origin,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Comparison share failed: $error\n$stackTrace');
      if (mounted) _showMessage('比較結果を共有できませんでした。もう一度お試しください。');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;
    return Scaffold(
      appBar: AppBar(
        title: const Text('比較'),
        actions: [
          Builder(
            builder: (shareContext) => IconButton(
              tooltip: '比較結果を共有',
              onPressed: () => _shareComparison(shareContext),
              icon: const Icon(Icons.share_outlined),
            ),
          ),
          IconButton(
            tooltip: '見積を追加',
            onPressed: _addQuote,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          if (!_adService.adFree.value)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'purchase') _purchaseRemoveAds();
                if (value == 'restore') _restorePurchases();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'purchase', child: Text('広告を削除')),
                PopupMenuItem(value: 'restore', child: Text('購入を復元')),
              ],
            ),
        ],
      ),
      bottomNavigationBar:
          banner != null && _bannerLoaded && !_adService.adFree.value
              ? SafeArea(
                  child: SizedBox(
                    width: banner.size.width.toDouble(),
                    height: banner.size.height.toDouble(),
                    child: AdWidget(ad: banner),
                  ),
                )
              : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              _report.projectName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              '順位・総合点は付けず、条件差と不明点を確認します。下へ引っ張ると再読み込みできます。',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _addQuote,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('PDF・写真から見積を追加'),
            ),
            const SizedBox(height: 16),
            _SummaryCard(lines: _report.summaryLines),
            const SizedBox(height: 16),
            _SnapshotList(snapshots: _report.quoteSnapshots),
            const SizedBox(height: 16),
            const _BadgeLegend(),
            const SizedBox(height: 16),
            if (_detailsUnlocked) ...[
              const Text(
                '18カテゴリ比較',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('表は左右にスクロールできます。', style: TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              _CategoryComparisonTable(report: _report),
              const SizedBox(height: 16),
              Text(
                '確認質問テンプレート (${_report.clarificationQuestions.length}件)',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ..._report.clarificationQuestions.map(
                (question) => _QuestionCard(question: question),
              ),
            ] else
              _DetailUnlockCard(
                loading: _unlocking,
                onUnlock: _unlockDetails,
                onRemoveAds: _purchaseRemoveAds,
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('3行サマリー', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...lines.asMap().entries.map(
                  (entry) => Text('${entry.key + 1}. ${entry.value}'),
                ),
          ],
        ),
      ),
    );
  }
}

class _SnapshotList extends StatelessWidget {
  const _SnapshotList({required this.snapshots});

  final List<QuoteSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: snapshots.isEmpty
          ? const Card(child: Center(child: Text('見積書を追加してください。')))
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: snapshots.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, index) => _SnapshotCard(snapshot: snapshots[index]),
            ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});

  final QuoteSnapshot snapshot;

  String _yen(int? value) =>
      value == null ? '未入力' : NumberFormat('#,##0', 'ja_JP').format(value);

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
              Text(snapshot.contractorName, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('提示総額: ${_yen(snapshot.totalAmountYen)}円'),
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

class _BadgeLegend extends StatelessWidget {
  const _BadgeLegend();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('表示の見方', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _LegendRow(label: '未入力', description: '金額・数量・仕様が見積書に記載されていません。'),
            _LegendRow(label: '別途', description: '提示総額には含まれず、追加費用になる可能性があります。'),
            _LegendRow(label: '不明', description: '記載またはOCR結果だけでは判断できず、業者への確認が必要です。'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(label, style: const TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(description, style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryComparisonTable extends StatelessWidget {
  const _CategoryComparisonTable({required this.report});

  final ComparisonReport report;

  @override
  Widget build(BuildContext context) {
    if (report.quoteSnapshots.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('比較する見積がありません。'),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 56,
          dataRowMinHeight: 112,
          dataRowMaxHeight: 136,
          columns: [
            const DataColumn(label: Text('カテゴリ')),
            for (final snapshot in report.quoteSnapshots)
              DataColumn(
                label: SizedBox(
                  width: 170,
                  child: Text(snapshot.contractorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
          ],
          rows: [
            for (final comparison in report.categoryComparisons)
              DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 120,
                      child: Text(comparison.category.nameJa, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  for (final snapshot in report.quoteSnapshots)
                    DataCell(
                      _ComparisonCellView(
                        cell: _findCell(comparison.cells, snapshot.quoteId),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  ComparisonCell? _findCell(List<ComparisonCell> cells, String quoteId) {
    for (final cell in cells) {
      if (cell.quoteId == quoteId) return cell;
    }
    return null;
  }
}

class _ComparisonCellView extends StatelessWidget {
  const _ComparisonCellView({required this.cell});

  final ComparisonCell? cell;

  String _amount(int? value) => value == null
      ? '未入力'
      : '${NumberFormat('#,##0', 'ja_JP').format(value)}円';

  String _quantity(double? quantity, String? unit) {
    if (quantity == null) return '未入力';
    final text = quantity == quantity.roundToDouble()
        ? quantity.toInt().toString()
        : quantity.toString();
    return '$text${unit ?? ''}';
  }

  @override
  Widget build(BuildContext context) {
    final value = cell;
    if (value == null) return const SizedBox(width: 170, child: Text('未入力'));

    return SizedBox(
      width: 170,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text(value.inclusionStatus.labelJa, style: const TextStyle(fontSize: 11)),
          ),
          Text('金額: ${_amount(value.amountYen)}'),
          Text('数量: ${_quantity(value.quantity, value.unit)}'),
          Text('仕様: ${value.specification ?? "未入力"}', maxLines: 2, overflow: TextOverflow.ellipsis),
          if (value.uncertaintyReasons.isNotEmpty)
            Text(
              '確認: ${value.uncertaintyReasons.join(" / ")}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11),
            ),
        ],
      ),
    );
  }
}

class _DetailUnlockCard extends StatelessWidget {
  const _DetailUnlockCard({
    required this.loading,
    required this.onUnlock,
    required this.onRemoveAds,
  });

  final bool loading;
  final VoidCallback onUnlock;
  final VoidCallback onRemoveAds;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.table_chart_outlined, size: 40),
            const SizedBox(height: 8),
            const Text('詳細比較を表示', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('カテゴリ別の金額・仕様差と、業者への確認質問を表示します。'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loading ? null : onUnlock,
              icon: const Icon(Icons.ondemand_video_outlined),
              label: Text(loading ? '広告を準備中…' : '広告を見て詳細を表示'),
            ),
            TextButton(onPressed: onRemoveAds, child: const Text('広告を削除')),
          ],
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({required this.question});

  final ClarificationQuestion question;

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
