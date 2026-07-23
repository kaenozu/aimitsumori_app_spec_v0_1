library;

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../scanner_models.dart';

class ScanQualityService {
  const ScanQualityService();

  Future<ScanQualityResult> evaluateFile(String path) async {
    final bytes = await File(path).readAsBytes();
    return compute(_evaluateFileBytes, bytes);
  }

  ScanQualityResult evaluateLuma({
    required int width,
    required int height,
    required Uint8List luma,
    int? bytesPerRow,
    double motion = 0,
    bool detectRotation = true,
  }) {
    final rowStride = bytesPerRow ?? width;
    if (width < 8 ||
        height < 8 ||
        rowStride < width ||
        luma.length < rowStride * height) {
      throw ArgumentError('invalid luma frame');
    }

    int valueAt(int x, int y) => luma[y * rowStride + x];

    final pixelCount = width * height;
    final step = math.max(1, (pixelCount / 40000).floor());
    var sum = 0.0;
    var sumSquared = 0.0;
    var samples = 0;
    var dark = 0;
    var documentPixels = 0;
    for (var offset = 0; offset < pixelCount; offset += step) {
      final x = offset % width;
      final y = offset ~/ width;
      final value = valueAt(x, y).toDouble();
      sum += value;
      sumSquared += value * value;
      samples++;
      if (value < 55) dark++;
      if (value >= 170) documentPixels++;
    }
    final mean = sum / samples;
    final variance = math.max(0, sumSquared / samples - mean * mean);
    final contrast = math.sqrt(variance) / 128;
    final documentCoverage = documentPixels / samples;

    var laplacianSum = 0.0;
    var laplacianSquared = 0.0;
    var edgeSamples = 0;
    final sampleStride = math.max(1, step ~/ 2);
    for (var y = 1; y < height - 1; y += sampleStride) {
      for (var x = 1; x < width - 1; x += sampleStride) {
        final center = valueAt(x, y) * 4;
        final laplacian =
            center -
            valueAt(x, y - 1) -
            valueAt(x, y + 1) -
            valueAt(x - 1, y) -
            valueAt(x + 1, y);
        final value = laplacian.toDouble();
        laplacianSum += value;
        laplacianSquared += value * value;
        edgeSamples++;
      }
    }
    final laplacianMean = edgeSamples == 0 ? 0.0 : laplacianSum / edgeSamples;
    final sharpness = edgeSamples == 0
        ? 0.0
        : math.sqrt(
                math.max(
                  0,
                  laplacianSquared / edgeSamples -
                      laplacianMean * laplacianMean,
                ),
              ) /
              80;

    final shadowRatio = dark / samples;
    final tileMeans = <double>[];
    const tiles = 4;
    for (var tileY = 0; tileY < tiles; tileY++) {
      for (var tileX = 0; tileX < tiles; tileX++) {
        var tileSum = 0.0;
        var count = 0;
        final startX = tileX * width ~/ tiles;
        final endX = (tileX + 1) * width ~/ tiles;
        final startY = tileY * height ~/ tiles;
        final endY = (tileY + 1) * height ~/ tiles;
        for (var y = startY; y < endY; y += math.max(1, step)) {
          for (var x = startX; x < endX; x += math.max(1, step)) {
            tileSum += valueAt(x, y);
            count++;
          }
        }
        tileMeans.add(count == 0 ? mean : tileSum / count);
      }
    }
    final minTile = tileMeans.reduce(math.min);
    final maxTile = tileMeans.reduce(math.max);
    final illuminationGap = (maxTile - minTile) / 255;

    final border = math.max(2, math.min(width, height) ~/ 20);
    final leftBright = _brightRatio(
      valueAt,
      left: 0,
      right: border,
      top: border,
      bottom: height - border,
    );
    final rightBright = _brightRatio(
      valueAt,
      left: width - border,
      right: width,
      top: border,
      bottom: height - border,
    );
    final topBright = _brightRatio(
      valueAt,
      left: border,
      right: width - border,
      top: 0,
      bottom: border,
    );
    final bottomBright = _brightRatio(
      valueAt,
      left: border,
      right: width - border,
      top: height - border,
      bottom: height,
    );
    final edgeValues = [leftBright, rightBright, topBright, bottomBright];
    final edgeMin = edgeValues.reduce(math.min);
    final edgeMax = edgeValues.reduce(math.max);
    final edgeBalance = (1 - (edgeMax - edgeMin)).clamp(0, 1).toDouble();

    final issues = <ScanQualityIssue>[];
    if (mean < 72) issues.add(ScanQualityIssue.tooDark);
    if (documentCoverage < 0.22) issues.add(ScanQualityIssue.tooFar);
    if (edgeMax > 0.58) issues.add(ScanQualityIssue.documentNotCentered);
    if (edgeBalance < 0.72) issues.add(ScanQualityIssue.tilted);
    if (detectRotation && width > height * 1.18) {
      issues.add(ScanQualityIssue.rotated);
    }
    if (shadowRatio > 0.22 || illuminationGap > 0.38) {
      issues.add(ScanQualityIssue.shadow);
    }
    if (sharpness < 0.62) issues.add(ScanQualityIssue.blurred);
    if (motion > 0.18) issues.add(ScanQualityIssue.shaky);

    final brightnessScore = 1 - ((mean - 165).abs() / 165).clamp(0, 1);
    final coverageScore = (documentCoverage / 0.55).clamp(0, 1).toDouble();
    final score =
        (brightnessScore * 0.16 +
                contrast.clamp(0, 1) * 0.12 +
                sharpness.clamp(0, 1) * 0.30 +
                (1 - illuminationGap).clamp(0, 1) * 0.12 +
                edgeBalance * 0.12 +
                coverageScore * 0.18 -
                motion.clamp(0, 1) * 0.25)
            .clamp(0, 1)
            .toDouble();

    return ScanQualityResult(
      score: score,
      brightness: mean / 255,
      contrast: contrast.clamp(0, 1).toDouble(),
      sharpness: sharpness.clamp(0, 1).toDouble(),
      shadowRatio: shadowRatio,
      edgeBalance: edgeBalance,
      documentCoverage: documentCoverage,
      issues: issues.toSet().toList(growable: false),
    );
  }

  double _brightRatio(
    int Function(int x, int y) valueAt, {
    required int left,
    required int right,
    required int top,
    required int bottom,
  }) {
    var bright = 0;
    var count = 0;
    final area = math.max(1, (right - left) * (bottom - top));
    final step = math.max(1, (area / 4000).floor());
    for (var y = top; y < bottom; y += step) {
      for (var x = left; x < right; x += step) {
        if (valueAt(x, y) >= 170) bright++;
        count++;
      }
    }
    return count == 0 ? 0 : bright / count;
  }
}

ScanQualityResult _evaluateFileBytes(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return const ScanQualityResult(
      score: 0,
      brightness: 0,
      contrast: 0,
      sharpness: 0,
      shadowRatio: 1,
      edgeBalance: 0,
      documentCoverage: 0,
      issues: [ScanQualityIssue.blurred],
    );
  }

  final oriented = img.bakeOrientation(decoded);
  final resized = oriented.width > 480
      ? img.copyResize(oriented, width: 480)
      : oriented;
  final luma = Uint8List(resized.width * resized.height);
  var index = 0;
  for (final pixel in resized) {
    luma[index++] = ((pixel.r * 0.299) + (pixel.g * 0.587) + (pixel.b * 0.114))
        .round()
        .clamp(0, 255)
        .toInt();
  }
  return const ScanQualityService().evaluateLuma(
    width: resized.width,
    height: resized.height,
    bytesPerRow: resized.width,
    luma: luma,
    detectRotation: true,
  );
}
