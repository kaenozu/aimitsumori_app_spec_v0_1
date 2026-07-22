/// ファイルパス: lib/screens/comparison_screen.dart
/// 比較画面 - アクセシブルな表・業者別カード表示
library;

import 'dart:math' as math;
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
import '../widgets/comparison_summary_card.dart';
import '../services/comparison_export_service.dart';
import '../widgets/accessibility_widgets.dart';
import 'quote_input_screen.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({
    super.key,
    required this.project,
    this.repository,
    this.adService,
    this.isHistorical = false,
  });

  final Project project;
  final ProjectRepository? repository;
  final AdService? adService;
  final bool isHistorical;

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
    if (!widget.isHistorical) {
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
    if (widget.isHistorical) {
      return report.copyWithHistorical();
    }
    return report;
  }

  Future<void> _saveReport({bool notifyOnError = false}) async {
    if (!widget.persistReport) return;
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
      if (mounted) setState(() => _bannerLoaded = false);
    }
  }

  Future<void> _refresh() async {
    try {
      if (!widget.persistReport) {
        setState(() => _report = _generateReport());
        return;
      }
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
    try {
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              QuoteEditScreen(project: _project, repository: _repository),
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
    await _adService.restorePurchases();
    if (mounted) _showMessage('購入履歴の復元を開始しました。');
  }

  Future<void> _showShareOptions(BuildContext shareContext) async {
    final origin = _shareOrigin(shareContext);
    final format = await showModalBottomSheet<_ShareFormat>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
        builder: (sheetContext) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Semantics(
                header: true,
                label: '比較結果を共有',
                child: const ListTile(
                  title: Text(
                    '比較結果を共有',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('共有する形式を選択してください。'),
                ),
              ),
              Semantics(
                button: true,
                label: 'PDF形式で比較結果を共有',
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, semanticLabel: ''),
                  title: const Text('PDF'),
                  subtitle: const Text('比較画面をPDFとして共有'),
                  onTap: () => Navigator.pop(sheetContext, _ShareFormat.pdf),
                ),
              ),
              Semantics(
                button: true,
                label: '画像形式で比較結果を共有',
                child: ListTile(
                  leading: const Icon(Icons.image_outlined, semanticLabel: ''),
                  title: const Text('画像'),
                  subtitle: const Text('比較画面をPNG画像として共有'),
                  onTap: () => Navigator.pop(sheetContext, _ShareFormat.image),
                ),
              ),
              Semantics(
                button: true,
                label: 'CSV形式で案件データを共有',
                child: ListTile(
                  leading: const Icon(Icons.table_view_outlined, semanticLabel: ''),
                  title: const Text('CSV'),
                  subtitle: const Text('案件データをExcel・Numbers向けに共有'),
                  onTap: () => Navigator.pop(sheetContext, _ShareFormat.csv),
                ),
              ),
              Semantics(
                button: true,
                label: 'テキスト形式で比較結果を共有',
                child: ListTile(
                  leading: const Icon(Icons.text_snippet_outlined, semanticLabel: ''),
                  title: const Text('テキスト'),
                  subtitle: const Text('比較結果を読みやすい文章として共有'),
                  onTap: () => Navigator.pop(sheetContext, _ShareFormat.text),
                ),
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
        case _ShareFormat.text:
          await SharePlus.instance.share(
            ShareParams(
              text: ComparisonExportService.toText(_report),
              subject: '${_report.projectName} 相見積もり比較',
              title: '比較結果をテキストで共有',
              sharePositionOrigin: origin,
            ),
          );
      }
    } catch (error, stackTrace) {
      debugPrint('Comparison share failed: $error\n$stackTrace');
      if (mounted) _showMessage('比較結果を共有できませんでした。CSVまたはテキスト形式もお試しください。');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<_CapturedComparison> _captureComparison() async {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _captureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary || renderObject.size.isEmpty) {
      throw StateError('比較画面のキャプチャ領域を取得できませんでした。');
    }

    const maxPixelDimension = 8192.0;
    final maxRatioForSize = math.min(
      maxPixelDimension / renderObject.size.width,
      maxPixelDimension / renderObject.size.height,
    );
    final pixelRatio = math.min(
      3.0,
      math.min(devicePixelRatio, maxRatioForSize),
    );
    if (!pixelRatio.isFinite || pixelRatio <= 0) {
      throw StateError('比較画面が大きすぎるため画像化できませんでした。');
    }
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    try {
      if (image.width > maxPixelDimension || image.height > maxPixelDimension) {
        throw StateError('比較画面の画像サイズが上限を超えました。');
      }
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('比較画面をPNGへ変換できませんでした。');
      }
      return _CapturedComparison(
        bytes: byteData.buffer.asUint8List(),
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
    final banner = _bannerAd;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final effectiveViewMode = largeText && _viewMode == ComparisonViewMode.table
        ? ComparisonViewMode.contractorCards
        : _viewMode;
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          label: '比較画面',
          child: const Text('比較'),
        ),
        actions: [
          Builder(
            builder: (shareContext) => AccessibleIconButton(
              label: '比較結果を共有',
              onPressed: () => _shareComparison(shareContext),
              icon: const Icon(Icons.share_outlined),
            ),
          ),
          AccessibleIconButton(
            label: '見積を追加',
            onPressed: _addQuote,
            icon: const Icon(Icons.document_scanner_outlined),
          ),
          if (!_adService.adFree.value)
            PopupMenuButton<String>(
              tooltip: '広告と購入のメニュー',
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
                  child: Semantics(
                    label: '広告',
                    container: true,
                    child: SizedBox(
                      width: banner.size.width.toDouble(),
                      height: banner.size.height.toDouble(),
                      child: AdWidget(ad: banner),
                    ),
                  ),
                )
              : null,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Semantics(
              header: true,
              child: Text(
                _report.projectName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '順位・総合点は付けず、条件差と不明点を確認します。下へ引っ張ると再読み込みできます。',
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: OutlinedButton.icon(
                onPressed: _addQuote,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: const Text('PDF・写真から見積を追加'),
              ),
            ),
            const SizedBox(height: 16),
            _SummaryCard(lines: _report.summaryLines),
            const SizedBox(height: 16),
            _SnapshotList(snapshots: _report.quoteSnapshots),
            const SizedBox(height: 16),
            const _BadgeLegend(),
            const SizedBox(height: 16),
            if (_detailsUnlocked) ...[
              Semantics(
                header: true,
                child: Text(
                  '18カテゴリ比較',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              ComparisonViewModeSwitcher(
                value: effectiveViewMode,
                onChanged: (value) => setState(() => _viewMode = value),
              ),
              if (largeText && _viewMode == ComparisonViewMode.table) ...[
                const SizedBox(height: 8),
                const Text('文字を大きく表示しているため、業者別カード形式で表示しています。'),
              ],
              const SizedBox(height: 12),
              if (effectiveViewMode == ComparisonViewMode.table)
                _AccessibleComparisonTable(report: _report)
              else
                _ContractorCardComparison(report: _report),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  '確認質問テンプレート (${_report.clarificationQuestions.length}件)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
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

class _EmptyComparisonCard extends StatelessWidget {
  const _EmptyComparisonCard({required this.onAddQuote});

  final VoidCallback onAddQuote;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '3行サマリー、${lines.join('、')}',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '3行サマリー',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ...lines.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${entry.key + 1}. ${entry.value}'),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

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

class _SnapshotList extends StatelessWidget {
  const _SnapshotList({required this.snapshots});

  final List<QuoteSnapshot> snapshots;

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('見積書を追加してください。')),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        final width = wide
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final snapshot in snapshots)
              SizedBox(width: width, child: _SnapshotCard(snapshot: snapshot)),
          ],
        );
      },
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({required this.snapshot});

  final QuoteSnapshot snapshot;

  String _yen(int? value) => value == null
      ? '未入力'
      : '${NumberFormat('#,##0', 'ja_JP').format(value)}円';

  @override
  Widget build(BuildContext context) {
    final label = [
      snapshot.contractorName,
      '提示総額 ${_yen(snapshot.totalAmountYen)}',
      '見積内 ${snapshot.includedCategoryCount}カテゴリ',
      '別途 ${snapshot.separateCategoryNames.length}カテゴリ',
      '任意 ${snapshot.optionalCategoryNames.length}カテゴリ',
      '含有不明 ${snapshot.unknownCategoryNames.length}カテゴリ',
      '不確実点 ${snapshot.uncertaintyCount}件',
    ].join('、');
    return Semantics(
      container: true,
      label: label,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.contractorName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text('提示総額: ${_yen(snapshot.totalAmountYen)}'),
              Text('見積内: ${snapshot.includedCategoryCount}カテゴリ'),
              Text(
                '別途: ${snapshot.separateCategoryNames.isEmpty ? 'なし' : snapshot.separateCategoryNames.join('、')}',
              ),
              Text(
                '任意: ${snapshot.optionalCategoryNames.isEmpty ? 'なし' : snapshot.optionalCategoryNames.join('、')}',
              ),
              Text('含有不明: ${snapshot.unknownCategoryNames.length}カテゴリ'),
              Text('不確実点: ${snapshot.uncertaintyCount}件'),
            ],
          ),
      ],
    );
  }

  String _yen(int? value) => value == null
      ? '未入力'
      : '${NumberFormat('#,##0', 'ja_JP').format(value)}円';
}

class _BadgeLegend extends StatelessWidget {
  const _BadgeLegend();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('表示の見方', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _LegendRow(
              icon: Icons.help_outline,
              label: '未入力',
              description: '金額・数量・仕様が見積書に記載されていません。',
            ),
            _LegendRow(
              icon: Icons.add_circle_outline,
              label: '別途',
              description: '提示総額には含まれず、追加費用になる可能性があります。',
            ),
            _LegendRow(
              icon: Icons.warning_amber_outlined,
              label: '不明',
              description: '記載またはOCR結果だけでは判断できず、業者への確認が必要です。',
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.icon,
    required this.label,
    required this.description,
  });

  final IconData icon;
  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, semanticLabel: label),
          const SizedBox(width: 8),
          Expanded(child: Text('$label: $description')),
        ],
      ),
    );
  }
}

class _AccessibleComparisonTable extends StatelessWidget {
  const _AccessibleComparisonTable({required this.report});

  final ComparisonReport report;

  @override
  Widget build(BuildContext context) {
    if (report.quoteSnapshots.isEmpty) {
      return const Card(child: ListTile(title: Text('比較する見積がありません。')));
    }
    final columnWidths = <int, TableColumnWidth>{
      0: const FixedColumnWidth(150),
      for (var index = 0; index < report.quoteSnapshots.length; index++)
        index + 1: const FixedColumnWidth(240),
    };
    return Semantics(
      container: true,
      label: '18カテゴリ比較表',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            border: TableBorder.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            columnWidths: columnWidths,
            children: [
              TableRow(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                children: [
                  const _TableCellPadding(
                    child: Text(
                      'カテゴリ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    isThreeLine: true,
                  ),
                  for (final snapshot in report.quoteSnapshots)
                    _TableCellPadding(
                      child: Text(
                        snapshot.contractorName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              for (final comparison in report.categoryComparisons)
                TableRow(
                  children: [
                    _TableCellPadding(
                      child: Semantics(
                        header: true,
                        child: Text(
                          comparison.category.nameJa,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    for (final snapshot in report.quoteSnapshots)
                      _TableCellPadding(
                        child: _ComparisonCellView(
                          contractorName: snapshot.contractorName,
                          categoryName: comparison.category.nameJa,
                          cell: _findCell(comparison.cells, snapshot.quoteId),
                        ),
                      ),
                  ],
                ),
            ],
          ),
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

class _TableCellPadding extends StatelessWidget {
  const _TableCellPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      );
}

class _ContractorCardComparison extends StatelessWidget {
  const _ContractorCardComparison({required this.report});

  final ComparisonReport report;

  @override
  Widget build(BuildContext context) {
    if (report.quoteSnapshots.isEmpty) {
      return const Card(child: ListTile(title: Text('比較する見積がありません。')));
    }
    return Column(
      children: [
        for (final snapshot in report.quoteSnapshots)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ExpansionTile(
              initiallyExpanded: true,
              title: Text(
                snapshot.contractorName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '提示総額: ${snapshot.totalAmountYen == null ? '未入力' : '${NumberFormat('#,##0', 'ja_JP').format(snapshot.totalAmountYen)}円'}',
              ),
              children: [
                for (final comparison in report.categoryComparisons)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comparison.category.nameJa,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        _ComparisonCellView(
                          contractorName: snapshot.contractorName,
                          categoryName: comparison.category.nameJa,
                          cell: _findCell(comparison.cells, snapshot.quoteId),
                        ),
                        const Divider(height: 20),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
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
  const _ComparisonCellView({
    required this.contractorName,
    required this.categoryName,
    required this.cell,
  });

  final String contractorName;
  final String categoryName;
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
    if (value == null) {
      return Semantics(
        label: '$contractorName、$categoryName、状態 未入力',
        child: _statusBadge(context, InclusionStatus.unknown),
      );
    }
    final semanticLabel = [
      contractorName,
      categoryName,
      '状態 ${value.inclusionStatus.labelJa}',
      '金額 ${_amount(value.amountYen)}',
      '数量 ${_quantity(value.quantity, value.unit)}',
      '仕様 ${value.specification ?? '未入力'}',
      if (value.uncertaintyReasons.isNotEmpty)
        '確認事項 ${value.uncertaintyReasons.join('、')}',
    ].join('、');
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _statusBadge(context, value.inclusionStatus),
          const SizedBox(height: 8),
          Text('金額: ${_amount(value.amountYen)}'),
          Text('数量: ${_quantity(value.quantity, value.unit)}'),
          Text('仕様: ${value.specification ?? '未入力'}'),
          if (value.uncertaintyReasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '確認: ${value.uncertaintyReasons.join(' / ')}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(BuildContext context, InclusionStatus status) {
    final colorScheme = Theme.of(context).colorScheme;
    final config = switch (status) {
      InclusionStatus.included => (
          Icons.check_circle_outline,
          colorScheme.primaryContainer,
          colorScheme.onPrimaryContainer,
        ),
      InclusionStatus.separate => (
          Icons.add_circle_outline,
          colorScheme.tertiaryContainer,
          colorScheme.onTertiaryContainer,
        ),
      InclusionStatus.optional => (
          Icons.tune_outlined,
          colorScheme.secondaryContainer,
          colorScheme.onSecondaryContainer,
        ),
      InclusionStatus.excluded => (
          Icons.cancel_outlined,
          colorScheme.errorContainer,
          colorScheme.onErrorContainer,
        ),
      InclusionStatus.notApplicable => (
          Icons.remove_circle_outline,
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
      InclusionStatus.unknown => (
          Icons.help_outline,
          colorScheme.surfaceContainerHighest,
          colorScheme.onSurfaceVariant,
        ),
    };
    return AccessibleStatusBadge(
      label: status.labelJa,
      icon: config.$1,
      backgroundColor: config.$2,
      foregroundColor: config.$3,
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
            Text(
              '詳細比較を表示',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            const Text('カテゴリ別の金額・仕様差と、業者への確認質問を表示します。'),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton.icon(
                onPressed: loading ? null : onUnlock,
                icon: const Icon(Icons.ondemand_video_outlined),
                label: Text(loading ? '広告を準備中…' : '広告を見て詳細を表示'),
              ),
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
    return Semantics(
      container: true,
      label: '確認質問、${question.questionText}',
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.templateKey,
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              Text(question.questionText),
            ],
          ),
        ),
      ),
    );
  }
}
