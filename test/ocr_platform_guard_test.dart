import 'package:aimitsumori_app/services/ocr_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('rejects OCR extraction on desktop platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    final service = OcrService();
    try {
      expect(
        () => service.extractQuote('missing-estimate.jpg'),
        throwsA(
          isA<OcrException>().having(
            (error) => error.message,
            'message',
            'OCR取込はAndroid・iOSで利用できます。',
          ),
        ),
      );
    } finally {
      await service.dispose();
    }
  });

  test('reports desktop platforms as unsupported', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;

    expect(OcrService.isSupportedPlatform, isFalse);
  });
}
