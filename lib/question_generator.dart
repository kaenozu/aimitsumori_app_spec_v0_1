/// ファイルパス: lib/domain/question_generator.dart
/// 不明事項から質問文を生成する
/// 関連ファイル: lib/models.dart

import 'dart:convert';
import '../models.dart';

class QuestionGenerator {
  List<ClarificationQuestion> generate({
    required Project project,
    required List<NormalizedQuote> normalizedQuotes,
    int? nowEpochMillis,
  }) {
    final now = nowEpochMillis ?? DateTime.now().millisecondsSinceEpoch;
    final questions = <ClarificationQuestion>[];

    for (final quote in normalizedQuotes) {
      for (final line in quote.lines) {
        questions.addAll(_questionsForLine(
          projectId: project.id,
          quote: quote,
          line: line,
          nowEpochMillis: now,
        ));
      }
    }

    return questions;
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
          '${contractorName}様：${categoryName}は見積金額に含まれていますか。含む・別途・対象外のいずれかをご回答ください。'
        ));
      case InclusionStatus.separate:
        rawQuestions.add((
          'SEPARATE_SCOPE',
          '${contractorName}様：別途扱いの${categoryName}は工事に必須ですか。必要な場合の追加金額と発生条件をご提示ください。'
        ));
      case InclusionStatus.optional:
        rawQuestions.add((
          'OPTIONAL_SCOPE',
          '${contractorName}様：オプション扱いの${categoryName}について、採用時の追加金額と標準仕様との差をご提示ください。'
        ));
      default:
        break;
    }

    final requiresDetail = line.inclusionStatus != InclusionStatus.excluded &&
        line.inclusionStatus != InclusionStatus.notApplicable;

    if (line.amountYen == null && requiresDetail) {
      rawQuestions.add((
        'MISSING_AMOUNT',
        '${contractorName}様：${categoryName}の金額が不明です。税込・税抜の別も含めて金額をご提示ください。'
      ));
    }

    if (requiresDetail && line.category.quantityExpected &&
        (line.quantity == null || line.unit == null)) {
      rawQuestions.add((
        'MISSING_QUANTITY',
        '${contractorName}様：${categoryName}の数量と単位、および算定根拠をご提示ください。'
      ));
    }

    if (requiresDetail && line.category.specificationExpected &&
        line.specification == null) {
      rawQuestions.add((
        'MISSING_SPECIFICATION',
        '${contractorName}様：${categoryName}の製品名・型番・寸法・施工仕様をご提示ください。'
      ));
    }

    final seen = <String>{};
    return rawQuestions.where((q) => seen.add(q.$1)).map((q) {
      final idSource = '$projectId|${quote.quoteId}|${line.category.id}|${q.$1}';
      final id = _uuidFromBytes(utf8.encode(idSource));
      return ClarificationQuestion(
        id: id,
        projectId: projectId,
        quoteId: quote.quoteId,
        contractorName: contractorName,
        categoryId: line.category.id,
        templateKey: q.$1,
        questionText: q.$2,
        createdAtEpochMillis: nowEpochMillis,
      );
    }).toList();
  }

  /// UUID v5 equivalent (name-based) for deterministic IDs
  static String _uuidFromBytes(List<int> bytes) {
    // Simple hash-based UUID for deterministic IDs
    int hash = 0;
    for (final b in bytes) {
      hash = ((hash << 5) - hash + b) & 0xFFFFFFFF;
    }
    final hex = hash.toRadixString(16).padLeft(8, '0');
    return '$hex-0000-4000-8000-${DateTime.now().millisecondsSinceEpoch.toRadixString(16).padLeft(12, '0').substring(0, 12)}';
  }
}
