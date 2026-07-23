/// 見積書を複数ページ撮影し、画質確認後にまとめてOCRする画面。
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../repositories/project_repository.dart';
import '../scanner_models.dart';
import '../services/batch_ocr_service.dart';
import '../services/scan_quality_service.dart';
import '../services/scan_storage_service.dart';
import 'scanner_ocr_review_screen.dart';

class DocumentScannerScreen extends StatefulWidget {
  const DocumentScannerScreen({
    super.key,
    required this.project,
    this.repository,
    this.qualityService = const ScanQualityService(),
    this.storageService = const ScanStorageService(),
  });

  final Project project;
  final ProjectRepository? repository;
  final ScanQualityService qualityService;
  final ScanStorageService storageService;

  @override
  State<DocumentScannerScreen> createState() => _DocumentScannerScreenState();
}

class _DocumentScannerScreenState extends State<DocumentScannerScreen>
    with WidgetsBindingObserver {
  static const _analysisInterval = Duration(milliseconds: 450);
  static const _stableDuration = Duration(milliseconds: 1100);
  static const _captureCooldown = Duration(seconds: 2);

  final BatchOcrService _batchOcrService = BatchOcrService();
  final List<ScannedPage> _pages = [];
  late final String _sessionId =
      'scan-${DateTime.now().millisecondsSinceEpoch}';

  CameraController? _controller;
  ScanQualityResult? _quality;
  Uint8List? _previousLuma;
  DateTime _lastAnalyzedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastCapturedAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _stableSince;
  bool _initializing = true;
  bool _capturing = false;
  bool _processing = false;
  bool _autoCapture = true;
  bool _awaitingDocumentChange = false;
  bool _flashEnabled = false;
  int _initializationToken = 0;
  int? _retakeIndex;
  String? _error;
  String? _notice;

  ProjectRepository get _repository =>
      widget.repository ?? ProjectRepository.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (controller != null) unawaited(_disposeController());
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    final token = ++_initializationToken;
    if (mounted) {
      setState(() {
        _initializing = true;
        _error = null;
      });
    }
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'カメラが見つかりません。');
      }
      final camera = cameras.firstWhere(
        (item) => item.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      await _disposeController(invalidateInitialization: false);
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted || token != _initializationToken) {
        await controller.dispose();
        return;
      }
      await controller.setFlashMode(
        _flashEnabled ? FlashMode.torch : FlashMode.off,
      );
      if (!mounted || token != _initializationToken) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.startImageStream(_analyzeFrame);
      if (mounted) setState(() => _initializing = false);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = error.code == 'CameraAccessDenied'
            ? 'カメラの使用が許可されていません。端末設定からカメラ権限を許可してください。'
            : 'カメラを開始できませんでした: ${error.description ?? error.code}';
      });
    } catch (error, stackTrace) {
      debugPrint('Camera initialization failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'カメラを開始できませんでした。';
      });
    }
  }

  Future<void> _disposeController({
    bool invalidateInitialization = true,
  }) async {
    if (invalidateInitialization) _initializationToken++;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (error) {
        debugPrint('Camera image stream stop failed: $error');
      }
    }
    await controller.dispose();
  }

  void _analyzeFrame(CameraImage image) {
    if (_capturing || _processing) return;
    final now = DateTime.now();
    if (now.difference(_lastAnalyzedAt) < _analysisInterval) return;
    _lastAnalyzedAt = now;

    final plane = image.planes.first;
    final current = plane.bytes;
    final motion = _calculateMotion(current);
    final result = widget.qualityService.evaluateLuma(
      width: image.width,
      height: image.height,
      bytesPerRow: plane.bytesPerRow,
      luma: current,
      motion: motion,
      detectRotation: false,
    );
    _previousLuma = Uint8List.fromList(current);

    if (result.isAcceptable) {
      _stableSince ??= now;
    } else {
      _stableSince = null;
      _awaitingDocumentChange = false;
    }
    if (mounted) setState(() => _quality = result);

    final stableSince = _stableSince;
    if (_autoCapture &&
        !_awaitingDocumentChange &&
        stableSince != null &&
        now.difference(stableSince) >= _stableDuration &&
        now.difference(_lastCapturedAt) >= _captureCooldown) {
      _stableSince = null;
      unawaited(_capturePage(auto: true));
    }
  }

  double _calculateMotion(Uint8List current) {
    final previous = _previousLuma;
    if (previous == null || previous.length != current.length) return 0;
    final step = math.max(1, current.length ~/ 8000);
    var difference = 0.0;
    var count = 0;
    for (var index = 0; index < current.length; index += step) {
      difference += (current[index] - previous[index]).abs();
      count++;
    }
    return count == 0 ? 0 : (difference / count / 255).clamp(0, 1).toDouble();
  }

  Future<void> _capturePage({bool auto = false}) async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        _capturing ||
        _processing) {
      return;
    }
    setState(() {
      _capturing = true;
      _error = null;
      _notice = null;
    });

    XFile? temporary;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      temporary = await controller.takePicture();
      final quality = await widget.qualityService.evaluateFile(temporary.path);
      if (auto && !quality.isAcceptable) {
        await _deleteTemporary(temporary.path);
        temporary = null;
        if (mounted) setState(() => _notice = quality.guidance);
        return;
      }

      final pageId = 'page-${DateTime.now().microsecondsSinceEpoch}';
      final persistedPath = await widget.storageService.persistCapture(
        sourcePath: temporary.path,
        projectId: widget.project.id,
        sessionId: _sessionId,
        pageId: pageId,
      );
      await _deleteTemporary(temporary.path);
      temporary = null;
      final page = ScannedPage(
        id: pageId,
        path: persistedPath,
        capturedAtEpochMillis: DateTime.now().millisecondsSinceEpoch,
        quality: quality,
      );
      if (!mounted) return;
      setState(() {
        final retakeIndex = _retakeIndex;
        if (retakeIndex != null && retakeIndex < _pages.length) {
          final oldPage = _pages[retakeIndex];
          _pages[retakeIndex] = page;
          unawaited(widget.storageService.deletePath(oldPage.path));
          _retakeIndex = null;
        } else {
          _pages.add(page);
        }
        _lastCapturedAt = DateTime.now();
        _awaitingDocumentChange = auto;
        _notice = auto ? '自動撮影しました。次のページに替えてください。' : '撮影しました。続けて次のページを撮影できます。';
      });
    } on CameraException catch (error) {
      if (mounted) {
        setState(() {
          _error = '撮影できませんでした: ${error.description ?? error.code}';
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Capture processing failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = '撮影画像を保存できませんでした。');
    } finally {
      if (temporary != null) await _deleteTemporary(temporary.path);
      if (_controller == controller &&
          controller.value.isInitialized &&
          !controller.value.isStreamingImages) {
        try {
          await controller.startImageStream(_analyzeFrame);
        } catch (error) {
          debugPrint('Camera image stream restart failed: $error');
        }
      }
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _deleteTemporary(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (error) {
      debugPrint('Camera temporary file cleanup failed: $error');
    }
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    final next = !_flashEnabled;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      if (mounted) setState(() => _flashEnabled = next);
    } on CameraException {
      if (mounted) setState(() => _error = 'この端末ではライトを切り替えられません。');
    }
  }

  void _deletePage(int index) {
    final page = _pages.removeAt(index);
    unawaited(widget.storageService.deletePath(page.path));
    if (_retakeIndex == index) _retakeIndex = null;
    if (_retakeIndex != null && _retakeIndex! > index) {
      _retakeIndex = _retakeIndex! - 1;
    }
    setState(() {});
  }

  void _retakePage(int index) {
    setState(() {
      _retakeIndex = index;
      _notice = '第${index + 1}ページを再撮影します。書類をガイドに合わせてください。';
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final page = _pages.removeAt(oldIndex);
      _pages.insert(newIndex, page);
      _retakeIndex = null;
    });
  }

  Future<void> _finish() async {
    if (_pages.isEmpty || _processing) return;
    setState(() {
      _processing = true;
      _error = null;
      _notice = '全ページをまとめてOCR処理しています。';
    });
    try {
      final result = await _batchOcrService.extractPages(
        _pages.map((page) => page.path).toList(growable: false),
      );
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => ScannerOcrReviewScreen(
            project: widget.project,
            repository: _repository,
            result: result,
          ),
        ),
      );
      if (saved == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (error, stackTrace) {
      debugPrint('Batch OCR failed: $error\n$stackTrace');
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _processing = false;
          _notice = null;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_disposeController());
    unawaited(_batchOcrService.dispose());
    unawaited(
      widget.storageService.cleanupSession(
        projectId: widget.project.id,
        sessionId: _sessionId,
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('書類スキャン ${_pages.length}ページ'),
        actions: [
          IconButton(
            tooltip: _flashEnabled ? 'ライトを消す' : 'ライトを点ける',
            onPressed: _toggleFlash,
            icon: Icon(_flashEnabled ? Icons.flash_on : Icons.flash_off),
          ),
          IconButton(
            tooltip: _autoCapture ? '自動撮影をオフ' : '自動撮影をオン',
            onPressed: () => setState(() => _autoCapture = !_autoCapture),
            icon: Icon(
              _autoCapture ? Icons.auto_awesome : Icons.touch_app_outlined,
            ),
          ),
          TextButton(
            onPressed: _pages.isEmpty || _processing ? null : _finish,
            child: Text(
              _processing ? 'OCR中…' : '完了',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_initializing)
                    const Center(child: CircularProgressIndicator())
                  else if (controller != null && controller.value.isInitialized)
                    Center(
                      child: AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: CameraPreview(controller),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(
                        Icons.no_photography_outlined,
                        color: Colors.white,
                        size: 64,
                      ),
                    ),
                  const IgnorePointer(
                    child: CustomPaint(painter: _DocumentGuidePainter()),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: _GuidanceBanner(
                      quality: _quality,
                      error: _error,
                      notice: _notice,
                      autoCapture: _autoCapture,
                      awaitingDocumentChange: _awaitingDocumentChange,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 20,
                    child: Center(
                      child: SizedBox.square(
                        dimension: 72,
                        child: FloatingActionButton.large(
                          heroTag: 'scanner-shutter',
                          onPressed: _capturing || _processing
                              ? null
                              : () => _capturePage(),
                          child: _capturing
                              ? const CircularProgressIndicator()
                              : const Icon(Icons.camera_alt, size: 32),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_pages.isNotEmpty)
              SizedBox(
                height: 132,
                child: ReorderableListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(8),
                  itemCount: _pages.length,
                  onReorder: _reorder,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return _PageThumbnail(
                      key: ValueKey(page.id),
                      page: page,
                      index: index,
                      selectedForRetake: _retakeIndex == index,
                      onDelete: () => _deletePage(index),
                      onRetake: () => _retakePage(index),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceBanner extends StatelessWidget {
  const _GuidanceBanner({
    required this.quality,
    required this.error,
    required this.notice,
    required this.autoCapture,
    required this.awaitingDocumentChange,
  });

  final ScanQualityResult? quality;
  final String? error;
  final String? notice;
  final bool autoCapture;
  final bool awaitingDocumentChange;

  @override
  Widget build(BuildContext context) {
    final result = quality;
    final message =
        error ??
        notice ??
        (awaitingDocumentChange
            ? '次のページに替えてください'
            : result?.guidance ?? '書類の四隅をガイドに合わせてください');
    final acceptable = result?.isAcceptable == true && error == null;
    return Semantics(
      liveRegion: true,
      label: message,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: acceptable
              ? Colors.green.withValues(alpha: 0.88)
              : Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                acceptable ? Icons.check_circle : Icons.info_outline,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              if (autoCapture)
                const Tooltip(
                  message: '画質が安定すると自動撮影します',
                  child: Icon(Icons.auto_awesome, color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageThumbnail extends StatelessWidget {
  const _PageThumbnail({
    super.key,
    required this.page,
    required this.index,
    required this.selectedForRetake,
    required this.onDelete,
    required this.onRetake,
  });

  final ScannedPage page;
  final int index;
  final bool selectedForRetake;
  final VoidCallback onDelete;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      margin: const EdgeInsets.only(right: 8),
      decoration: BoxDecoration(
        color: selectedForRetake ? Colors.amber.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
              child: Image.file(
                File(page.path),
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: Text(' ${index + 1}頁')),
              IconButton(
                tooltip: '第${index + 1}ページを再撮影',
                visualDensity: VisualDensity.compact,
                onPressed: onRetake,
                icon: const Icon(Icons.refresh, size: 18),
              ),
              IconButton(
                tooltip: '第${index + 1}ページを削除',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DocumentGuidePainter extends CustomPainter {
  const _DocumentGuidePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final guide = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.82,
      height: size.height * 0.68,
    );
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    const corner = 28.0;
    for (final path in [
      Path()
        ..moveTo(guide.left + corner, guide.top)
        ..lineTo(guide.left, guide.top)
        ..lineTo(guide.left, guide.top + corner),
      Path()
        ..moveTo(guide.right - corner, guide.top)
        ..lineTo(guide.right, guide.top)
        ..lineTo(guide.right, guide.top + corner),
      Path()
        ..moveTo(guide.left, guide.bottom - corner)
        ..lineTo(guide.left, guide.bottom)
        ..lineTo(guide.left + corner, guide.bottom),
      Path()
        ..moveTo(guide.right, guide.bottom - corner)
        ..lineTo(guide.right, guide.bottom)
        ..lineTo(guide.right - corner, guide.bottom),
    ]) {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
