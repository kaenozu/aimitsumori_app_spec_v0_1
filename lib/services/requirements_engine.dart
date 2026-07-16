/// ユーザー要望と正規化済み見積の差異を判定する。
library;

import '../models.dart';
import '../requirements_models.dart';

class RequirementsEngine {
  const RequirementsEngine();

  List<RequirementAssessment> evaluate({
    required List<ProjectRequirement> requirements,
    required List<NormalizedQuote> quotes,
  }) {
    final results = <RequirementAssessment>[];
    for (final quote in quotes) {
      final lines = <String, NormalizedLine>{
        for (final line in quote.lines) line.category.id: line,
      };
      for (final requirement in requirements) {
        final line = lines[requirement.categoryId];
        if (line == null) continue;
        results.add(
          RequirementAssessment(
            requirement: requirement,
            quoteId: quote.quoteId,
            contractorName: quote.contractorName,
            status: _coverageStatus(requirement, line),
            line: line,
            mismatches: _mismatches(requirement, line),
          ),
        );
      }
    }
    return results;
  }

  RequirementCoverageStatus _coverageStatus(
    ProjectRequirement requirement,
    NormalizedLine line,
  ) {
    switch (requirement.priority) {
      case RequirementPriority.required:
        if (line.sourceLineItemIds.isEmpty ||
            line.inclusionStatus == InclusionStatus.unknown ||
            line.inclusionStatus == InclusionStatus.excluded ||
            line.inclusionStatus == InclusionStatus.notApplicable) {
          return RequirementCoverageStatus.requiredMissing;
        }
        if (line.inclusionStatus == InclusionStatus.separate ||
            line.inclusionStatus == InclusionStatus.optional) {
          return RequirementCoverageStatus.requiredSeparate;
        }
        return RequirementCoverageStatus.requiredIncluded;
      case RequirementPriority.optional:
        return line.sourceLineItemIds.isNotEmpty &&
                line.inclusionStatus == InclusionStatus.included
            ? RequirementCoverageStatus.optionalIncluded
            : RequirementCoverageStatus.optionalMissing;
      case RequirementPriority.unnecessary:
        final hasCharge = line.inclusionStatus == InclusionStatus.included ||
            (line.amountYen ?? 0) > 0;
        return hasCharge
            ? RequirementCoverageStatus.unnecessaryIncluded
            : RequirementCoverageStatus.noIssue;
      case RequirementPriority.unset:
        return RequirementCoverageStatus.unset;
    }
  }

  List<RequirementMismatch> _mismatches(
    ProjectRequirement requirement,
    NormalizedLine line,
  ) {
    if (requirement.priority == RequirementPriority.unset ||
        requirement.priority == RequirementPriority.unnecessary) {
      return const [];
    }

    final mismatches = <RequirementMismatch>[];
    final expectedQuantity = requirement.expectedQuantity;
    if (expectedQuantity != null) {
      final actualQuantity = line.quantity;
      if (actualQuantity == null) {
        mismatches.add(
          RequirementMismatch(
            type: RequirementMismatchType.quantity,
            message: '希望数量 ${_formatNumber(expectedQuantity)}'
                '${_text(requirement.expectedUnit)}に対し、見積数量の記載がありません。',
          ),
        );
      } else if ((actualQuantity - expectedQuantity).abs() > 0.01) {
        mismatches.add(
          RequirementMismatch(
            type: RequirementMismatchType.quantity,
            message: '希望数量 ${_formatNumber(expectedQuantity)}'
                '${_text(requirement.expectedUnit)} / 見積 ${_formatNumber(actualQuantity)}'
                '${_text(line.unit)}',
          ),
        );
      }
    }

    final expectedUnit = requirement.expectedUnit?.trim();
    final actualUnit = line.unit?.trim();
    if (expectedUnit != null &&
        expectedUnit.isNotEmpty &&
        actualUnit != null &&
        actualUnit.isNotEmpty &&
        expectedUnit != actualUnit) {
      mismatches.add(
        RequirementMismatch(
          type: RequirementMismatchType.unit,
          message: '希望単位 $expectedUnit / 見積単位 $actualUnit',
        ),
      );
    }

    final desired = requirement.desiredSpecification?.trim();
    if (desired != null && desired.isNotEmpty) {
      final actual = line.specification?.trim();
      if (actual == null || actual.isEmpty) {
        mismatches.add(
          RequirementMismatch(
            type: RequirementMismatchType.specification,
            message: '希望仕様「$desired」に対し、見積仕様の記載がありません。',
          ),
        );
      } else if (!_normalize(actual).contains(_normalize(desired))) {
        mismatches.add(
          RequirementMismatch(
            type: RequirementMismatchType.specification,
            message: '希望仕様「$desired」 / 見積仕様「$actual」',
          ),
        );
      }
    }
    return mismatches;
  }

  String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static String _text(String? value) => value?.trim() ?? '';

  static String _formatNumber(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
}
