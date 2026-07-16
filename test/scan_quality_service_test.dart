import 'dart:typed_data';

import 'package:aimitsumori_app/scanner_models.dart';
import 'package:aimitsumori_app/services/scan_quality_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = ScanQualityService();

  Uint8List checkerboard(int width, int height, {int? bytesPerRow}) {
    final stride = bytesPerRow ?? width;
    final bytes = Uint8List(stride * height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final border = x < 8 || y < 8 || x >= width - 8 || y >= height - 8;
        bytes[y * stride + x] = border
            ? 40
            : ((x ~/ 4 + y ~/ 4).isEven ? 220 : 120);
      }
    }
    return bytes;
  }

  test('sharp centered document is not reported as blur or rotation', () {
    final result = service.evaluateLuma(
      width: 120,
      height: 180,
      luma: checkerboard(120, 180),
    );

    expect(result.issues, isNot(contains(ScanQualityIssue.blurred)));
    expect(result.issues, isNot(contains(ScanQualityIssue.rotated)));
    expect(result.documentCoverage, greaterThan(0.22));
    expect(result.score, greaterThan(0.5));
  });

  test('dark flat frame detects darkness and blur', () {
    final result = service.evaluateLuma(
      width: 120,
      height: 180,
      luma: Uint8List.fromList(List.filled(120 * 180, 30)),
    );

    expect(result.issues, contains(ScanQualityIssue.tooDark));
    expect(result.issues, contains(ScanQualityIssue.blurred));
    expect(result.isAcceptable, isFalse);
  });

  test('small bright document area asks user to move closer', () {
    final luma = Uint8List.fromList(List.filled(120 * 180, 80));
    for (var y = 70; y < 110; y++) {
      for (var x = 40; x < 80; x++) {
        luma[y * 120 + x] = 220;
      }
    }

    final result = service.evaluateLuma(
      width: 120,
      height: 180,
      luma: luma,
    );

    expect(result.issues, contains(ScanQualityIssue.tooFar));
    expect(result.guidance, '見積書に近づいてください');
  });

  test('motion detects camera shake', () {
    final result = service.evaluateLuma(
      width: 120,
      height: 180,
      luma: checkerboard(120, 180),
      motion: 0.4,
    );

    expect(result.issues, contains(ScanQualityIssue.shaky));
  });

  test('landscape captured document detects rotation', () {
    final result = service.evaluateLuma(
      width: 180,
      height: 120,
      luma: checkerboard(180, 120),
    );

    expect(result.issues, contains(ScanQualityIssue.rotated));
  });

  test('camera row padding is handled', () {
    final result = service.evaluateLuma(
      width: 120,
      height: 180,
      bytesPerRow: 128,
      luma: checkerboard(120, 180, bytesPerRow: 128),
      detectRotation: false,
    );

    expect(result.sharpness, greaterThan(0));
    expect(result.issues, isNot(contains(ScanQualityIssue.rotated)));
  });
}
