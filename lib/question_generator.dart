/// 不明事項とユーザー要望との差から質問文を生成する。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'data/category_master.dart';
import 'models.dart';
import 'requirements_models.dart';
import 'services/requirements_engine.dart';

class QuestionGenerator {
  List<ClarificationQuestion> generate({
    required Project project,
    required List<NormalizedQuote> normalizedQuotes,
    List<ProjectRequirement> requirements = const [],
    int? nowEpochMillis,
  }) {
    final now = nowEpochMillis ?? DateTime.now().millisecondsSinceEpoch;
    final questions = <ClarificationQuestion>[];

    for (final quote in normalizedQuotes) {
      for (final line in quote.lines) {
        questions.addAll(
          _questionsForLine(
            projectId: project.id,
            quote: quote,
            line: line,
            nowEpochMillis: now,
          ),
        );
      }
    }

    if (requirements.isNotEmpty) {
      final assessments = const RequirementsEngine().evaluate(
        requirements: requirements,
        quotes: normalizedQuotes,
      );
      for (final assessment in assessments) {
        questions.addAll(
          _questionsForRequirement(
            projectId: project.id,
            assessment: assessment,
            nowEpochMillis: now,
          ),
        );
      }
    }

    final byId = <String, ClarificationQuestion>{};
    for (final question in questions) {
      byId[question.id] = question;
    }
    return byId.values.toList(growable: false);
  }

  List<ClarificationQuestion> _questionsForLine({
    required String projectId,
    required NormalizedQuote quote,
    required NormalizedLine line,
    required int nowEpochMillis,
  }) {
    final categoryName = line.category.nameJa;
    final contractorName = quote.contractorName;
    final rawQuestions = <(String, String)>[];

    switch (line.inclusionStatus) {
      case InclusionStatus.unknown:
        rawQuestions.add((
          'UNKNOWN_INCLUSION',
          '$contractorName様：$categoryNameは見積金額に含まれていますか。含む・別途・対象外のいずれかをご回答ください。',
        ));
      case InclusionStatus.separate:
        rawQuestions.add((
          'SEPARATE_SCOPE',
          '$contractorName様：別途扱いの$categoryNameは工事に必須ですか。必要な場合の追加金額と発生条件をご提示ください。',
        ));
      case InclusionStatus.optional:
        rawQuestions.add((
          'OPTIONAL_SCOPE',
          '$contractorName様：オプション扱いの$categoryNameについて、採用時の追加金額と標準仕様との差をご提示ください。',
        ));
      default:
        break;
    }

    final requiresDetail =
        line.inclusionStatus != InclusionStatus.excluded &&
        line.inclusionStatus != InclusionStatus.notApplicable;

    if (line.amountYen == null && requiresDetail) {
      rawQuestions.add((
        'MISSING_AMOUNT',
        '$contractorName様：$categoryNameの金額が不明です。税込・税抜の別も含めて金額をご提示ください。',
      ));
    }

    if (requiresDetail &&
        line.category.quantityExpected &&
        (line.quantity == null || line.unit == null)) {
      rawQuestions.add((
        'MISSING_QUANTITY',
        '$contractorName様：$categoryNameの数量と単位、および算定根拠をご提示ください。',
      ));
    }

    if (requiresDetail &&
        line.category.specificationExpected &&
        line.specification == null) {
      rawQuestions.add((
        'MISSING_SPECIFICATION',
        '$contractorName様：$categoryNameの製品名・型番・寸法・施工仕様をご提示ください。',
      ));
    }

    return _deduplicate(rawQuestions).map((question) {
      return _question(
        projectId: projectId,
        quoteId: quote.quoteId,
        contractorName: contractorName,
        categoryId: line.category.id,
        templateKey: question.$1,
        questionText: question.$2,
        nowEpochMillis: nowEpochMillis,
      );
    }).toList();
  }

  List<ClarificationQuestion> _questionsForRequirement({
    required String projectId,
    required RequirementAssessment assessment,
    required int nowEpochMillis,
  }) {
    final category = CategoryMaster.require(assessment.requirement.categoryId);
    final contractor = assessment.contractorName;
    final rawQuestions = <(String, String)>[];

    switch (assessment.status) {
      case RequirementCoverageStatus.requiredSeparate:
        rawQuestions.add((
          'REQUIREMENT_REQUIRED_SEPARATE',
          '$contractor様：必須として希望している${category.nameJa}は総額に含まれていますか。別途の場合は追加金額と施工条件をご提示ください。',
        ));
      case RequirementCoverageStatus.requiredMissing:
        rawQuestions.add((
          'REQUIREMENT_REQUIRED_MISSING',
          '$contractor様：必須として希望している${category.nameJa}の記載が確認できません。見積内・別途・対象外のいずれかをご回答ください。',
        ));
      case RequirementCoverageStatus.unnecessaryIncluded:
        rawQuestions.add((
          'REQUIREMENT_UNNECESSARY_INCLUDED',
          '$contractor様：${category.nameJa}は不要としていますが見積に計上されています。削除可否と減額金額をご提示ください。',
        ));
      default:
        break;
    }

    final quantityMessages = assessment.mismatches
        .where((value) => value.type == RequirementMismatchType.quantity)
        .map((value) => value.message)
        .toList(growable: false);
    final unitMessages = assessment.mismatches
        .where((value) => value.type == RequirementMismatchType.unit)
        .map((value) => value.message)
        .toList(growable: false);
    final specificationMessages = assessment.mismatches
        .where((value) => value.type == RequirementMismatchType.specification)
        .map((value) => value.message)
        .toList(growable: false);

    if (quantityMessages.isNotEmpty) {
      rawQuestions.add((
        'REQUIREMENT_QUANTITY_MISMATCH',
        '$contractor様：${category.nameJa}の希望数量との差を確認したいです。'
            '${quantityMessages.join(' ')} 差が生じた理由と算定根拠をご提示ください。',
      ));
    }
    if (unitMessages.isNotEmpty) {
      rawQuestions.add((
        'REQUIREMENT_UNIT_MISMATCH',
        '$contractor様：${category.nameJa}の希望単位との差を確認したいです。'
            '${unitMessages.join(' ')} 正しい数量と単位をご提示ください。',
      ));
    }
    if (specificationMessages.isNotEmpty) {
      rawQuestions.add((
        'REQUIREMENT_SPECIFICATION_MISMATCH',
        '$contractor様：${category.nameJa}の希望仕様との差を確認したいです。'
            '${specificationMessages.join(' ')} 同等仕様か、変更が必要かをご回答ください。',
      ));
    }

    return _deduplicate(rawQuestions).map((question) {
      return _question(
        projectId: projectId,
        quoteId: assessment.quoteId,
        contractorName: contractor,
        categoryId: category.id,
        templateKey: question.$1,
        questionText: question.$2,
        nowEpochMillis: nowEpochMillis,
      );
    }).toList();
  }

  Iterable<(String, String)> _deduplicate(List<(String, String)> values) {
    final seen = <String>{};
    return values.where((value) => seen.add(value.$1));
  }

  ClarificationQuestion _question({
    required String projectId,
    required String quoteId,
    required String contractorName,
    required String categoryId,
    required String templateKey,
    required String questionText,
    required int nowEpochMillis,
  }) {
    final idSource = '$projectId|$quoteId|$categoryId|$templateKey';
    return ClarificationQuestion(
      id: _uuidFromDigest(sha256.convert(utf8.encode(idSource)).bytes),
      projectId: projectId,
      quoteId: quoteId,
      contractorName: contractorName,
      categoryId: categoryId,
      templateKey: templateKey,
      questionText: questionText,
      createdAtEpochMillis: nowEpochMillis,
    );
  }

  static String _uuidFromDigest(List<int> digest) {
    final bytes = List<int>.from(digest.take(16));
    bytes[6] = (bytes[6] & 0x0f) | 0x50;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
