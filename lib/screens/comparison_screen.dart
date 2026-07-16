/// ファイルパス: lib/screens/comparison_screen.dart
/// 比較画面 - サマリー、リワード解放する詳細比較、質問テンプレート、バナー広告
/// 関連ファイル: lib/models.dart, lib/normalizer.dart, lib/services/ad_service.dart
library;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';

import '../comparison_engine.dart';
import '../models.dart';
import '../normalizer.dart';
import '../question_generator.dart';
import '../repositories/project_repository.dart';
import '../services/ad_service.dart';
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

  ProjectRepository get _repository => widget.repository ?? ProjectRepository.instance;
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

  Future<void> _saveReport() async {
    try {
      await _repository.saveComparisonResult(_report);
    } catch (error) {
      debugPrint('Comparison result save failed: $error');
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
    final ad = _adService.createBannerAd(
      onLoaded: () {
        if (mounted) setState(() => _bannerLoaded = true);
      },
      onFailed: (error) {
        debugPrint('Banner ad failed to load: $error');
        if (mounted) setState(() => _bannerLoaded = false);
      },
    );
    _bannerAd = ad;
    ad?.load();
  }

  Future<void> _addQuote() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteInputScreen(
          project: _project,
          repository: _repository,
        ),
      ),
    );
    if (saved != true) return;

    final refreshed = await _repository.getProject(_project.id);
    if (!mounted || refreshed == null) return;
    setState(() {
      _project = refreshed;
      _report = _generateReport();
      _detailsUnlocked = _adService.adFree.value;
    });
    await _saveReport();
  }

  Future<void> _unlockDetails() async {
    if (_detailsUnlocked || _unlocking) return;
    setState(() => _unlocking = true);
    final unlocked = await _adService.showRewardedAd();
    if (!mounted) return;
    setState(() {
      _unlocking = false;
      _detailsUnlocked = unlocked;
    });
    if (!unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('広告を最後まで視聴すると詳細比較を表示できます。')),
      );
    }
  }

  Future<void> _purchaseRemoveAds() async {
    final started = await _adService.purchaseRemoveAds();
    if (!mounted) return;
    if (!started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('購入商品を取得できませんでした。ストア設定を確認してください。')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final banner = _bannerAd;
    return Scaffold(
      appBar: AppBar(
        title: const Text('比較'),
        actions: [
          IconButton(
            tooltip: '見積を追加',
            onPressed: _addQuote,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          if (!_adService.adFree.value)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'purchase') _purchaseRemoveAds();
                if (value == 'restore') _adService.restorePurchases();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'purchase', child: Text('広告を削除')),
                PopupMenuItem(value: 'restore', child: Text('購入を復元')),
              ],
            ),
        ],
      ),
      bottomNavigationBar: banner != null && _bannerLoaded && !_adService.adFree.value
          ? SafeArea(
              child: SizedBox(
                width: banner.size.width.toDouble(),
                height: banner.size.height.toDouble(),
                child: AdWidget(ad: banner),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _report.projectName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            '順位・総合点は付けず、条件差と不明点を確認します。',
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
          SizedBox(
            height: 160,
            child: _report.quoteSnapshots.isEmpty
                ? const Card(child: Center(child: Text('見積書を追加してください。')))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _report.quoteSnapshots.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, index) => _SnapshotCard(
                      snapshot: _report.quoteSnapshots[index],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          if (_detailsUnlocked) ...[
            const Text('18カテゴリ比較', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._report.categoryComparisons.map((value) => _CategoryCard(comparison: value)),
            const SizedBox(height: 16),
            Text(
              '確認質問テンプレート (${_report.clarificationQuestions.length}件)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._report.clarificationQuestions.map((value) => _QuestionCard(question: value)),
          ] else
            _DetailUnlockCard(
              loading: _unlocking,
              onUnlock: _unlockDetails,
              onRemoveAds: _purchaseRemoveAds,
            ),
          const SizedBox(height: 24),
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
            const Text('3行サマリー', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...lines.asMap().entries.map((entry) => Text('${entry.key + 1}. ${entry.value}')),
          ],
        ),
      ),
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});

  final QuoteSnapshot snapshot;

  String _format(int? value) =>
      value != null ? NumberFormat('#,##0', 'ja_JP').format(value) : '不明';

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
              Text('提示総額: ${_format(snapshot.totalAmountYen)}円'),
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
  const _CategoryCard({required this.comparison});

  final CategoryComparison comparison;

  String _format(int? value) =>
      value != null ? NumberFormat('#,##0', 'ja_JP').format(value) : '不明';

  String _formatQuantity(double? quantity, String? unit) {
    if (quantity == null || unit == null) return '不明';
    return quantity == quantity.roundToDouble() ? '${quantity.toInt()} $unit' : '$quantity $unit';
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
            ...comparison.cells.asMap().entries.map((entry) {
              final cell = entry.value;
              final isLast = entry.key == comparison.cells.length - 1;
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
                    Text('金額: ${_format(cell.amountYen)}円'),
                    Text('数量: ${_formatQuantity(cell.quantity, cell.unit)}'),
                    Text('仕様: ${cell.specification ?? "不明"}'),
                    if (cell.uncertaintyReasons.isNotEmpty)
                      Text(
                        '不明・確認: ${cell.uncertaintyReasons.join(" / ")}',
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
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
