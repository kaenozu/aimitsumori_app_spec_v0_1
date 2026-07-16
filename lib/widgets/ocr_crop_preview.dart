library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../ocr_models.dart';

class OcrCropPreview extends StatefulWidget {
  const OcrCropPreview({super.key, required this.line, this.height = 92});

  final OcrRecognizedLine line;
  final double height;

  @override
  State<OcrCropPreview> createState() => _OcrCropPreviewState();
}

class _OcrCropPreviewState extends State<OcrCropPreview> {
  ui.Image? _image;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant OcrCropPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.sourceImagePath != widget.line.sourceImagePath) {
      _image?.dispose();
      _image = null;
      _error = null;
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.line.sourceImagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    return Semantics(
      label: '元見積書 ${widget.line.pageNumber}ページの該当箇所',
      image: true,
      child: Container(
        height: widget.height,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: image != null
            ? CustomPaint(
                painter: _CropPainter(
                  image: image,
                  rect: widget.line.boundingRect,
                ),
              )
            : Center(
                child: _error == null
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('元画像を表示できません', textAlign: TextAlign.center),
              ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  const _CropPainter({required this.image, required this.rect});

  final ui.Image image;
  final OcrBoundingRect rect;

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalPadding = 36.0;
    const verticalPadding = 20.0;
    final left = (rect.left - horizontalPadding).clamp(
      0.0,
      image.width.toDouble(),
    );
    final top = (rect.top - verticalPadding).clamp(
      0.0,
      image.height.toDouble(),
    );
    final right = (rect.right + horizontalPadding).clamp(
      left + 1,
      image.width.toDouble(),
    );
    final bottom = (rect.bottom + verticalPadding).clamp(
      top + 1,
      image.height.toDouble(),
    );
    final source = Rect.fromLTRB(left, top, right, bottom);
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.drawImageRect(image, source, Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _CropPainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.rect != rect;
}
