/// ファイルパス: lib/screens/comparison_screen.dart
/// 比較画面 - 表形式と業者別カード形式、共有、広告解除を提供する。
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../comparison_engine.dart';
import '../models.dart';
import '../normalizer.dart';
import '../question_generator.dart';
import '../repositories/project_repository.dart';
import '../services/ad_service.dart';
import '../services/comparison_export_service.dart';
import '../widgets/accessibility_widgets.dart';
import '../widgets/comparison_summary_card.dart';
import 'quote_input_screen.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({
    super.key,
    required this.project,
    this.repository,
    this.adService,
    this.isHistorical = false,
    this.persistReport = true,
    this.allowQuoteEditing = true,
  });

  final Project project;
  final ProjectRepository? repository;
  final AdService? adService;
  final bool isHistorical;
  final bool persistReport;
  final bool allowQuoteEditing;

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final GlobalKey _captureKey = GlobalKey();

  late Project _project;
  late ComparisonReport _report;
  BannerAd? _bannerAd;
  bool _bannerLoaded = false;
  bool _detailsUnlocked = false;
  bool _unlocking = false;
  bool _exporting = false;
  ComparisonViewMode _viewMode = ComparisonViewMode.table;

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
    if (widget.persistReport && !widget.isHistorical) {
      _saveReport();
    }
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
    final report = ComparisonEngine().compare(
      project: _project,
      normalizedQuotes: normalized,
      questions: questions,
    );
    return widget.isHistorical ? report.copyWithHistorical() : report;
  }

  Future<void> _saveReport({bool notifyOnError = false}) async {
    if (!widget.persistReport || widget.isHistorical) return;
    try {
      await _repository.saveComparisonResult(_report);
    } catch (error, stackTrace) {
      debugPrint('Comparison result save failed: $error\n$stackTrace');
      if (notifyOnError && mounted) _showMessage(error.toString());
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
    }
  }

  Future<void> _refresh() async {
    if (!widget.persistReport) {
      setState(() => _report = _generateReport());
      return;
    }
    try {
      final refreshed = await _repository.getProject(_project.id);
      if (refreshed == null) {
        throw const ProjectRepositoryException('案件の再読み込み', 'project not found');
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
    if (!widget.allowQuoteEditing) return;
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            QuoteInputScreen(project: _project, repository: _repository),
      ),
    );
    if (saved == true) await _refresh();
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
    await _adService.restorePurchases();
    if (mounted) _showMessage('購入履歴の復元を開始しました。');
  }

  Future<void> _showShareOptions(BuildContext shareContext) async {
    final origin = _shareOrigin(shareContext);
    final format = await showModalBottomSheet<_ShareFormat>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text(
                '比較結果を共有',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('共有する形式を選択してください。'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('PDF'),
              subtitle: const Text('比較画面をPDFとして共有'),
              onTap: () => Navigator.pop(sheetContext, _ShareFormat.pdf),
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: const Text('画像'),
              subtitle: const Text('比較画面をPNG画像として共有'),
              onTap: () => Navigator.pop(sheetContext, _ShareFormat.image),
            ),
            ListTile(
              leading: const Icon(Icons.table_view_outlined),
              title: const Text('CSV'),
              subtitle: const Text('案件データをExcel・Numbers向けに共有'),
              onTap: () => Navigator.pop(sheetContext, _ShareFormat.csv),
            ),
            ListTile(
              leading: const Icon(Icons.text_snippet_outlined),
              title: const Text('テキスト'),
              subtitle: const Text('比較結果を読みやすい文章として共有'),
              onTap: () => Navigator.pop(sheetContext, _ShareFormat.text),
            ),
          ],
        ),
      ),
    );
    if (format != null && mounted) await _shareComparison(format, origin);
  }

  Rect? _shareOrigin(BuildContext shareContext) {
    final renderObject = shareContext.findRenderObject();
    return renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
  }

  Future<void> _shareComparison(_ShareFormat format, Rect? origin) async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final fileStem = ComparisonExportService.fileStem(_report.projectName);
      switch (format) {
        case _ShareFormat.pdf:
          final captured = await _captureComparison();
          final pdfBytes = await ComparisonExportService.toPdfFromImage(
            captured.bytes,
            imageWidth: captured.logicalWidth,
            imageHeight: captured.logicalHeight,
          );
          await Printing.sharePdf(
            bytes: pdfBytes,
            filename: '${fileStem}_比較結果.pdf',
          );
          break;
        case _ShareFormat.image:
          final captured = await _captureComparison();
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile.fromData(captured.bytes, mimeType: 'image/png')],
              fileNameOverrides: ['${fileStem}_比較結果.png'],
              subject: '${_report.projectName} 相見積もり比較',
              title: '比較結果を画像で共有',
              sharePositionOrigin: origin,
            ),
          );
          break;
        case _ShareFormat.csv:
          await SharePlus.instance.share(
            ShareParams(
              files: [
                XFile.fromData(
                  ComparisonExportService.toCsvBytes(_project),
                  mimeType: 'text/csv',
                ),
              ],
              fileNameOverrides: ['${fileStem}_案件データ.csv'],
              subject: '${_project.name} 案件データ',
              title: '案件データをCSVで共有',
              sharePositionOrigin: origin,
            ),
          );
          break;
        case _ShareFormat.text:
          await SharePlus.instance.share(
            ShareParams(
              text: ComparisonExportService.toText(_report),
              subject: '${_report.projectName} 相見積もり比較',
              title: '比較結果をテキストで共有',
              sharePositionOrigin: origin,
            ),
          );
          break;
      }
    } catch (error, stackTrace) {
      debugPrint('Comparison share failed: $error\n$stackTrace');
      if (mounted) {
        _showMessage('比較結果を共有できませんでした。CSVまたはテキスト形式もお試しください。');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<_CapturedComparison> _captureComparison() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _captureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || renderObject.size.isEmpty) {
      throw StateError('比較画面のキャプチャ領域を取得できませんでした。');
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(
      context,
    ).clamp(1.0, 3.0).toDouble();
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('比較画面の画像を生成できませんでした。');
      return _CapturedComparison(
        bytes: data.buffer.asUint8List(),
        logicalWidth: renderObject.size.width,
        logicalHeight: renderObject.size.height,
      );
    } finally {
      image.dispose();
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    return Scaffold(
      appBar: AppBar(
        title: const Text('比較'),
        actions: [
          if (widget.allowQuoteEditing)
            AccessibleIconButton(
              label: '見積を追加',
              icon: const Icon(Icons.add),
              onPressed: _addQuote,
            ),
          Builder(
            builder: (shareContext) => AccessibleIconButton(
              label: _exporting ? '共有データを作成中' : '共有',
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
              enabled: !_exporting,
              onPressed: () => _showShareOptions(shareContext),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            RepaintBoundary(
              key: _captureKey,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        _project.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('順位や総合点ではなく、価格・範囲・不明点を並べて確認します。'),
                    if (largeText) ...[
                      const SizedBox(height: 8),
                      const Text('文字を大きく表示しているため、表は横方向へスクロールできます。'),
                    ],
                    const SizedBox(height: 16),
                    if (_project.quotes.isEmpty)
                      _EmptyComparison(
                        onAddQuote: widget.allowQuoteEditing ? _addQuote : null,
                      )
                    else ...[
                      ComparisonSummaryCard(lines: _report.summaryLines),
                      const SizedBox(height: 12),
                      _QuoteOverview(snapshots: _report.quoteSnapshots),
                      const SizedBox(height: 16),
                      if (!_detailsUnlocked)
                        _UnlockCard(
                          unlocking: _unlocking,
                          onUnlock: _unlockDetails,
                          onPurchase: _purchaseRemoveAds,
                          onRestore: _restorePurchases,
                        )
                      else ...[
                        ComparisonViewModeSwitcher(
                          value: _viewMode,
                          onChanged: (value) =>
                              setState(() => _viewMode = value),
                        ),
                        const SizedBox(height: 12),
                        if (_viewMode == ComparisonViewMode.table)
                          _ComparisonTable(report: _report)
                        else
                          _ContractorCards(report: _report),
                        if (_report.clarificationQuestions.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _QuestionList(
                            questions: _report.clarificationQuestions,
                          ),
                        ],
                      ],
                    ],
                  ],
                ),
              ),
            ),
            if (_bannerLoaded && _bannerAd != null) ...[
              const SizedBox(height: 16),
              Center(
                child: SizedBox(
                  width: _bannerAd!.size.width.toDouble(),
                  height: _bannerAd!.size.height.toDouble(),
                  child: AdWidget(ad: _bannerAd!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyComparison extends StatelessWidget {
  const _EmptyComparison({required this.onAddQuote});

  final VoidCallback? onAddQuote;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.description_outlined, size: 48),
          const SizedBox(height: 12),
          Text('まず1社目の見積を入れます', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('PDF・写真・手入力から見積を登録できます。'),
          if (onAddQuote != null) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAddQuote,
              icon: const Icon(Icons.add),
              label: const Text('見積書を追加する'),
            ),
          ],
        ],
      ),
    ),
  );
}

class _QuoteOverview extends StatelessWidget {
  const _QuoteOverview({required this.snapshots});

  final List<QuoteSnapshot> snapshots;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('見積概要', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final snapshot in snapshots)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${snapshot.contractorName}（見積概要）'),
              subtitle: Text(
                '別途 ${snapshot.separateCategoryNames.length}件 / '
                '不明 ${snapshot.unknownCategoryNames.length}件',
              ),
              trailing: Text(_formatYen(snapshot.totalAmountYen)),
            ),
        ],
      ),
    ),
  );
}

class _UnlockCard extends StatelessWidget {
  const _UnlockCard({
    required this.unlocking,
    required this.onUnlock,
    required this.onPurchase,
    required this.onRestore,
  });

  final bool unlocking;
  final VoidCallback onUnlock;
  final VoidCallback onPurchase;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text('カテゴリ別の詳細比較を見る'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: unlocking ? null : onUnlock,
            child: Text(unlocking ? '広告を読み込み中…' : '広告を見て表示'),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              TextButton(onPressed: onPurchase, child: const Text('広告を削除')),
              TextButton(onPressed: onRestore, child: const Text('購入を復元')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _ComparisonTable extends StatelessWidget {
  const _ComparisonTable({required this.report});

  final ComparisonReport report;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: DataTable(
      columns: [
        const DataColumn(label: Text('カテゴリ')),
        for (final quote in report.quoteSnapshots)
          DataColumn(label: Text(quote.contractorName)),
      ],
      rows: [
        for (final comparison in report.categoryComparisons)
          DataRow(
            cells: [
              DataCell(Text(comparison.category.nameJa)),
              for (final cell in comparison.cells)
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      '${cell.inclusionStatus.labelJa}\n'
                      '${_formatYen(cell.amountYen)}\n'
                      '${_formatQuantity(cell.quantity, cell.unit)}\n'
                      '${cell.specification ?? '仕様未入力'}',
                    ),
                  ),
                ),
            ],
          ),
      ],
    ),
  );
}

class _ContractorCards extends StatelessWidget {
  const _ContractorCards({required this.report});

  final ComparisonReport report;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final snapshot in report.quoteSnapshots)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.contractorName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text('提示総額: ${_formatYen(snapshot.totalAmountYen)}'),
                const Divider(),
                for (final comparison in report.categoryComparisons)
                  Builder(
                    builder: (context) {
                      final cell = comparison.cells.firstWhere(
                        (value) => value.quoteId == snapshot.quoteId,
                      );
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(comparison.category.nameJa),
                        subtitle: Text(
                          '${_formatYen(cell.amountYen)} / '
                          '${_formatQuantity(cell.quantity, cell.unit)}\n'
                          '${cell.specification ?? '仕様未入力'}',
                        ),
                        trailing: Text(cell.inclusionStatus.labelJa),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _QuestionList extends StatelessWidget {
  const _QuestionList({required this.questions});

  final List<ClarificationQuestion> questions;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('確認質問', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final question in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('・${question.questionText}'),
            ),
        ],
      ),
    ),
  );
}

String _formatYen(int? value) =>
    value == null ? '未入力' : '${NumberFormat('#,##0', 'ja_JP').format(value)}円';

String _formatQuantity(double? quantity, String? unit) {
  if (quantity == null) return '数量未入力';
  final text = quantity == quantity.roundToDouble()
      ? quantity.toInt().toString()
      : quantity.toString();
  return unit == null || unit.isEmpty ? text : '$text$unit';
}

enum _ShareFormat { pdf, image, csv, text }

class _CapturedComparison {
  const _CapturedComparison({
    required this.bytes,
    required this.logicalWidth,
    required this.logicalHeight,
  });

  final Uint8List bytes;
  final double logicalWidth;
  final double logicalHeight;
}
