/// ファイルパス: lib/question_generator.dart
/// 不明事項から質問文を生成する
/// 関連ファイル: lib/models.dart
library;

import 'dart:convert';

import 'models.dart';

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
          '${contractorName}様：$categoryNameは見積金額に含まれていますか。含む・別途・対象外のいずれかをご回答ください。',
        ));
      case InclusionStatus.separate:
        rawQuestions.add((
          'SEPARATE_SCOPE',
          '${contractorName}様：別途扱いの$categoryNameは工事に必須ですか。必要な場合の追加金額と発生条件をご提示ください。',
        ));
      case InclusionStatus.optional:
        rawQuestions.add((
          'OPTIONAL_SCOPE',
          '${contractorName}様：オプション扱いの$categoryNameについて、採用時の追加金額と標準仕様との差をご提示ください。',
        ));
      default:
        break;
    }

    final requiresDetail = line.inclusionStatus != InclusionStatus.excluded &&
        line.inclusionStatus != InclusionStatus.notApplicable;

    if (line.amountYen == null && requiresDetail) {
      rawQuestions.add((
        'MISSING_AMOUNT',
        '${contractorName}様：$categoryNameの金額が不明です。税込・税抜の別も含めて金額をご提示ください。',
      ));
    }

    if (requiresDetail &&
        line.category.quantityExpected &&
        (line.quantity == null || line.unit == null)) {
      rawQuestions.add((
        'MISSING_QUANTITY',
        '${contractorName}様：$categoryNameの数量と単位、および算定根拠をご提示ください。',
      ));
    }

    if (requiresDetail &&
        line.category.specificationExpected &&
        line.specification == null) {
      rawQuestions.add((
        'MISSING_SPECIFICATION',
        '${contractorName}様：$categoryNameの製品名・型番・寸法・施工仕様をご提示ください。',
      ));
    }

    final seen = <String>{};
    return rawQuestions.where((question) => seen.add(question.$1)).map((question) {
      final idSource = '$projectId|${quote.quoteId}|${line.category.id}|${question.$1}';
      final id = _uuidFromBytes(utf8.encode(idSource));
      return ClarificationQuestion(
        id: id,
        projectId: projectId,
        quoteId: quote.quoteId,
        contractorName: contractorName,
        categoryId: line.category.id,
        templateKey: question.$1,
        questionText: question.$2,
        createdAtEpochMillis: nowEpochMillis,
      );
    }).toList();
  }

  static String _uuidFromBytes(List<int> bytes) {
    var hashA = 0x811C9DC5;
    var hashB = 0x9E3779B9;
    for (final byte in bytes) {
      hashA = ((hashA ^ byte) * 0x01000193) & 0xFFFFFFFF;
      hashB = ((hashB + byte) * 31) & 0xFFFFFFFF;
    }
    final first = hashA.toRadixString(16).padLeft(8, '0');
    final second = (hashB & 0xFFFF).toRadixString(16).padLeft(4, '0');
    final tail = ((hashA << 16) ^ hashB).toUnsigned(48).toRadixString(16).padLeft(12, '0');
    return '$first-$second-5000-8000-$tail';
  }
}
