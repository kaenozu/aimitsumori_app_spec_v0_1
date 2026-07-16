/// ユーザー要望と見積内容の差異を表すモデル。
library;

import 'models.dart';

enum RequirementPriority {
  required('required', '必須'),
  optional('optional', 'あればよい'),
  unnecessary('unnecessary', '不要'),
  unset('unset', '未設定');

  const RequirementPriority(this.code, this.labelJa);

  final String code;
  final String labelJa;

  static RequirementPriority fromCode(String code) =>
      RequirementPriority.values.firstWhere(
        (value) => value.code == code,
        orElse: () => RequirementPriority.unset,
      );
}

class ProjectRequirement {
  const ProjectRequirement({
    required this.categoryId,
    this.priority = RequirementPriority.unset,
    this.expectedQuantity,
    this.expectedUnit,
    this.desiredSpecification,
    this.note,
  });

  final String categoryId;
  final RequirementPriority priority;
  final double? expectedQuantity;
  final String? expectedUnit;
  final String? desiredSpecification;
  final String? note;

  bool get isConfigured => priority != RequirementPriority.unset ||
      expectedQuantity != null ||
      _hasText(expectedUnit) ||
      _hasText(desiredSpecification) ||
      _hasText(note);

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;
}

enum RequirementCoverageStatus {
  requiredIncluded('必須かつ見積内'),
  requiredSeparate('必須だが別途'),
  requiredMissing('必須だが記載なし'),
  unnecessaryIncluded('不要だが計上あり'),
  optionalIncluded('あればよい・見積内'),
  optionalMissing('あればよい・記載なし'),
  noIssue('差異なし'),
  unset('要望未設定');

  const RequirementCoverageStatus(this.labelJa);
  final String labelJa;
}

enum RequirementMismatchType {
  quantity,
  unit,
  specification,
}

class RequirementMismatch {
  const RequirementMismatch({
    required this.type,
    required this.message,
  });

  final RequirementMismatchType type;
  final String message;
}

class RequirementAssessment {
  const RequirementAssessment({
    required this.requirement,
    required this.quoteId,
    required this.contractorName,
    required this.status,
    required this.line,
    this.mismatches = const [],
  });

  final ProjectRequirement requirement;
  final String quoteId;
  final String contractorName;
  final RequirementCoverageStatus status;
  final NormalizedLine line;
  final List<RequirementMismatch> mismatches;

  bool get hasDifference =>
      status == RequirementCoverageStatus.requiredSeparate ||
      status == RequirementCoverageStatus.requiredMissing ||
      status == RequirementCoverageStatus.unnecessaryIncluded ||
      mismatches.isNotEmpty;
}
