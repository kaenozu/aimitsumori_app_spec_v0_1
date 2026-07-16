/// ファイルパス: lib/screens/comparison_screen.dart
/// 比較画面 - 更新、PDF・画像・CSV・テキスト共有、カテゴリ比較、質問テンプレート、広告
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
import '../services/comparison_export_service.dart';
import 'quote_input_screen.dart';

enum _ShareFormat { pdf, image, csv, text }

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({
    super.key,
    required this.project,
    this.repository,
    this.adService,
    this.persistReport = true,
    this.allowQuoteEditing = true,
  });

  final Project project;
  final ProjectRepository? repository;
  final AdService? adService;
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
    if (widget.persistReport) _saveReport();
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
              QuoteInputScreen(project: _project, repository: _repository),
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
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('比較'),
        actions: [
          Builder(
            builder: (shareContext) => IconButton(
              tooltip: '比較結果を共有',
              onPressed: _exporting
                  ? null
                  : () => _showShareOptions(shareContext),
              icon: _exporting
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.share_outlined),
            ),
          ),
          if (widget.allowQuoteEditing)
            IconButton(
              tooltip: '見積を追加',
              onPressed: _addQuote,
              icon: const Icon(Icons.document_scanner_outlined),
            ),
          if (!_adService.adFree.value)
            PopupMenuButton<String>(
              tooltip: '広告と購入の設定',
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
          children: [
            RepaintBoundary(
              key: _captureKey,
              child: ColoredBox(
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _report.projectName,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      const Text('順位・総合点は付けず、条件差と不明点を確認します。'),
                      if (widget.allowQuoteEditing) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _addQuote,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('PDF・写真から見積を追加'),
                        ),
                      ],
                      const SizedBox(height: 16),
                      _SummaryCard(lines: _report.summaryLines),
                      const SizedBox(height: 16),
                      _SnapshotList(snapshots: _report.quoteSnapshots),
                      const SizedBox(height: 16),
                      const _BadgeLegend(),
                      const SizedBox(height: 16),
                      if (_detailsUnlocked) ...[
                        Text(
                          '18カテゴリ比較',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        _CategoryComparisonList(report: _report),
                        const SizedBox(height: 16),
                        Text(
                          '確認質問テンプレート (${_report.clarificationQuestions.length}件)',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        if (_report.clarificationQuestions.isEmpty)
                          const Card(
                            child: ListTile(title: Text('確認質問はありません。')),
                          )
                        else
                          for (final question in _report.clarificationQuestions)
                            _QuestionCard(question: question),
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
              ),
            ),
          ],
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
            for (var index = 0; index < lines.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('${index + 1}. ${lines[index]}'),
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
    if (snapshots.isEmpty) {
      return const Card(child: ListTile(title: Text('見積書を追加してください。')));
    }
    return Column(
      children: [
        for (final snapshot in snapshots)
          Card(
            child: ListTile(
              title: Text(snapshot.contractorName),
              subtitle: Text(
                '提示総額: ${_yen(snapshot.totalAmountYen)}\n'
                '見積内: ${snapshot.includedCategoryCount}カテゴリ / '
                '別途: ${snapshot.separateCategoryNames.length}件 / '
                '任意: ${snapshot.optionalCategoryNames.length}件\n'
                '含有不明: ${snapshot.unknownCategoryNames.length}カテゴリ / '
                '不確実点: ${snapshot.uncertaintyCount}件',
              ),
              isThreeLine: true,
            ),
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
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('表示の見方', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('未入力: 金額・数量・仕様が見積書に記載されていません。'),
            Text('別途: 提示総額には含まれず、追加費用になる可能性があります。'),
            Text('不明: 記載またはOCR結果だけでは判断できず、確認が必要です。'),
          ],
        ),
      ),
    );
  }
}

class _CategoryComparisonList extends StatelessWidget {
  const _CategoryComparisonList({required this.report});

  final ComparisonReport report;

  @override
  Widget build(BuildContext context) {
    if (report.quoteSnapshots.isEmpty) {
      return const Card(child: ListTile(title: Text('比較する見積がありません。')));
    }
    return Column(
      children: [
        for (final comparison in report.categoryComparisons)
          Card(
            child: ExpansionTile(
              title: Text(comparison.category.nameJa),
              children: [
                for (final cell in comparison.cells)
                  ListTile(
                    title: Text(cell.contractorName),
                    leading: Icon(_statusIcon(cell.inclusionStatus)),
                    subtitle: Text(
                      '${cell.inclusionStatus.labelJa}\n'
                      '金額: ${_amount(cell.amountYen)} / '
                      '数量: ${_quantity(cell.quantity, cell.unit)}\n'
                      '仕様: ${cell.specification ?? "未入力"}'
                      '${cell.uncertaintyReasons.isEmpty ? "" : "\n確認: ${cell.uncertaintyReasons.join(" / ")}"}',
                    ),
                    isThreeLine: true,
                  ),
              ],
            ),
          ),
      ],
    );
  }

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

  IconData _statusIcon(InclusionStatus status) => switch (status) {
    InclusionStatus.included => Icons.check_circle_outline,
    InclusionStatus.separate => Icons.add_circle_outline,
    InclusionStatus.optional => Icons.info_outline,
    InclusionStatus.excluded ||
    InclusionStatus.notApplicable => Icons.remove_circle_outline,
    InclusionStatus.unknown => Icons.help_outline,
  };
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
            const Text(
              '詳細比較を表示',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
            Text(
              question.templateKey,
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 4),
            SelectableText(question.questionText),
          ],
        ),
      ),
    );
  }
}
