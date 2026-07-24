library;

enum ScanQualityIssue {
  documentNotCentered('書類の四隅を枠内に合わせてください'),
  tooFar('見積書に近づいてください'),
  tilted('端末を書類と平行にしてください'),
  rotated('端末または書類の向きを直してください'),
  shadow('影が入らないように位置を調整してください'),
  blurred('ピントを合わせてください'),
  shaky('端末をしっかり固定してください'),
  tooDark('明るい場所で撮影してください');

  const ScanQualityIssue(this.messageJa);

  final String messageJa;
}

class ScanQualityResult {
  const ScanQualityResult({
    required this.score,
    required this.brightness,
    required this.contrast,
    required this.sharpness,
    required this.shadowRatio,
    required this.edgeBalance,
    required this.documentCoverage,
    required this.issues,
  });

  final double score;
  final double brightness;
  final double contrast;
  final double sharpness;
  final double shadowRatio;
  final double edgeBalance;
  final double documentCoverage;
  final List<ScanQualityIssue> issues;

  bool get isAcceptable => score >= 0.72 && issues.isEmpty;

  String get guidance {
    if (isAcceptable) return 'そのまま動かさずにお待ちください';
    if (issues.isNotEmpty) return issues.first.messageJa;
    return '書類の四隅をガイドに合わせてください';
  }
}

class ScannedPage {
  const ScannedPage({
    required this.id,
    required this.path,
    required this.capturedAtEpochMillis,
    required this.quality,
  });

  final String id;
  final String path;
  final int capturedAtEpochMillis;
  final ScanQualityResult quality;

  ScannedPage copyWith({String? path, ScanQualityResult? quality}) =>
      ScannedPage(
        id: id,
        path: path ?? this.path,
        capturedAtEpochMillis: capturedAtEpochMillis,
        quality: quality ?? this.quality,
      );
}
