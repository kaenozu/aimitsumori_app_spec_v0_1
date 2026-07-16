library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

enum OcrReviewStatus {
  pending('pending', '未確認'),
  confirmed('confirmed', '確認済み'),
  autoConfirmed('auto_confirmed', '自動確定');

  const OcrReviewStatus(this.code, this.labelJa);
  final String code;
  final String labelJa;

  static OcrReviewStatus fromCode(String code) =>
      OcrReviewStatus.values.firstWhere(
        (value) => value.code == code,
        orElse: () => OcrReviewStatus.pending,
      );
}

enum OcrReviewSeverity { warning, critical }

enum OcrReviewReason {
  lowOcrConfidence,
  lowCategoryConfidence,
  lowAmountConfidence,
  totalMismatch,
  quantityUnitPriceMismatch,
  multipleCandidates,
}

class OcrBoundingRect {
  const OcrBoundingRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  Map<String, Object?> toJson() => {
    'left': left,
    'top': top,
    'right': right,
    'bottom': bottom,
  };

  factory OcrBoundingRect.fromJson(Map<String, Object?> json) =>
      OcrBoundingRect(
        left: (json['left'] as num).toDouble(),
        top: (json['top'] as num).toDouble(),
        right: (json['right'] as num).toDouble(),
        bottom: (json['bottom'] as num).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OcrBoundingRect &&
          left == other.left &&
          top == other.top &&
          right == other.right &&
          bottom == other.bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

class OcrRecognizedLine {
  const OcrRecognizedLine({
    required this.pageNumber,
    required this.boundingRect,
    required this.confidence,
    required this.rawText,
    required this.sourceImagePath,
    required this.categoryConfidence,
    required this.amountConfidence,
    this.categoryCandidates = const [],
    this.amountCandidates = const [],
    this.reviewReasons = const [],
    this.initialStatus = OcrReviewStatus.autoConfirmed,
  });

  final int pageNumber;
  final OcrBoundingRect boundingRect;
  final double confidence;
  final String rawText;
  final String sourceImagePath;
  final double categoryConfidence;
  final double amountConfidence;
  final List<String> categoryCandidates;
  final List<int> amountCandidates;
  final List<OcrReviewReason> reviewReasons;
  final OcrReviewStatus initialStatus;

  String get id {
    final stableValue = [
      pageNumber,
      boundingRect.left.round(),
      boundingRect.top.round(),
      boundingRect.right.round(),
      boundingRect.bottom.round(),
      rawText,
    ].join('|');
    return sha256.convert(utf8.encode(stableValue)).toString();
  }

  bool get needsReview => reviewReasons.isNotEmpty;

  OcrReviewSeverity get severity =>
      reviewReasons.any(
        (reason) => reason == OcrReviewReason.quantityUnitPriceMismatch,
      )
      ? OcrReviewSeverity.critical
      : OcrReviewSeverity.warning;
}

class OcrReviewIssue {
  const OcrReviewIssue({
    required this.id,
    required this.reason,
    required this.severity,
    required this.message,
    this.lineId,
    this.initialStatus = OcrReviewStatus.pending,
  });

  final String id;
  final OcrReviewReason reason;
  final OcrReviewSeverity severity;
  final String message;
  final String? lineId;
  final OcrReviewStatus initialStatus;
}

class OcrReviewBundle {
  const OcrReviewBundle({required this.lines, required this.issues});

  final List<OcrRecognizedLine> lines;
  final List<OcrReviewIssue> issues;

  int criticalPendingCount(Map<String, OcrReviewStatus> statuses) => issues
      .where(
        (issue) =>
            issue.severity == OcrReviewSeverity.critical &&
            (statuses[issue.id] ?? issue.initialStatus) ==
                OcrReviewStatus.pending,
      )
      .length;
}
