from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise RuntimeError(f"Expected {label} block was not found")
    return text.replace(old, new, 1)


export_path = Path("lib/services/comparison_export_service.dart")
export_text = export_path.read_text(encoding="utf-8")
export_text = replace_once(
    export_text,
    "import 'dart:typed_data';\n",
    "import 'dart:typed_data';\nimport 'dart:ui' as ui;\n",
    "dart:ui import",
)
start_marker = "  /// 比較画面のキャプチャ画像を、その縦横比を保った1ページPDFへ変換する。\n"
end_marker = "\n  static String fileStem"
if "_splitPngIntoA4Pages" not in export_text:
    start = export_text.index(start_marker)
    end = export_text.index(end_marker, start)
    replacement = r'''  /// 比較画面のキャプチャ画像をA4比率で分割し、標準A4の複数ページPDFへ変換する。
  static Future<Uint8List> toPdfFromImage(
    Uint8List pngBytes, {
    required double imageWidth,
    required double imageHeight,
  }) async {
    if (pngBytes.isEmpty) {
      throw ArgumentError.value(pngBytes, 'pngBytes', '画像が空です。');
    }
    if (imageWidth <= 0 || imageHeight <= 0) {
      throw ArgumentError('画像サイズは0より大きい必要があります。');
    }

    final pageImages = await _splitPngIntoA4Pages(pngBytes);
    final document = pw.Document();
    for (final pageBytes in pageImages) {
      final image = pw.MemoryImage(pageBytes);
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Align(
            alignment: pw.Alignment.topCenter,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }
    return document.save();
  }

  static Future<List<Uint8List>> _splitPngIntoA4Pages(
    Uint8List pngBytes,
  ) async {
    final codec = await ui.instantiateImageCodec(pngBytes);
    try {
      final frame = await codec.getNextFrame();
      final source = frame.image;
      try {
        final a4AspectRatio = PdfPageFormat.a4.height / PdfPageFormat.a4.width;
        final sliceHeight = (source.width * a4AspectRatio)
            .floor()
            .clamp(1, source.height)
            .toInt();
        final pages = <Uint8List>[];
        for (var top = 0; top < source.height; top += sliceHeight) {
          final currentHeight = (source.height - top).clamp(1, sliceHeight);
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          canvas.drawImageRect(
            source,
            ui.Rect.fromLTWH(
              0,
              top.toDouble(),
              source.width.toDouble(),
              currentHeight.toDouble(),
            ),
            ui.Rect.fromLTWH(
              0,
              0,
              source.width.toDouble(),
              currentHeight.toDouble(),
            ),
            ui.Paint(),
          );
          final picture = recorder.endRecording();
          final pageImage = await picture.toImage(source.width, currentHeight);
          try {
            final data = await pageImage.toByteData(
              format: ui.ImageByteFormat.png,
            );
            if (data == null) {
              throw StateError('PDFページ用の画像を生成できませんでした。');
            }
            pages.add(data.buffer.asUint8List());
          } finally {
            pageImage.dispose();
            picture.dispose();
          }
        }
        return pages;
      } finally {
        source.dispose();
      }
    } finally {
      codec.dispose();
    }
  }
'''
    export_text = export_text[:start] + replacement + export_text[end:]
export_path.write_text(export_text, encoding="utf-8")

ad_path = Path("lib/services/ad_service.dart")
ad_text = ad_path.read_text(encoding="utf-8")
old_constructor = '''  @visibleForTesting
  AdService.testing({
    bool adFree = true,
    PurchaseVerifier verifier = const TestingPurchaseVerifier(),
  }) : _verifier = verifier {
    this.adFree.value = adFree;
    _initialized = true;
  }
'''
new_constructor = '''  @visibleForTesting
  factory AdService.testing({
    bool adFree = true,
    PurchaseVerifier verifier = const TestingPurchaseVerifier(),
  }) {
    final service = AdService._(verifier: verifier);
    service.adFree.value = adFree;
    service._initialized = true;
    return service;
  }
'''
ad_text = replace_once(ad_text, old_constructor, new_constructor, "AdService testing constructor")
ad_path.write_text(ad_text, encoding="utf-8")
