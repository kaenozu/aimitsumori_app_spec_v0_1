/// ファイルパス: lib/models.dart
/// 相見積もりアプリの全ドメインモデル定義
/// 関連ファイル: data/category_master.dart, data/sample_data.dart
library;

enum InclusionStatus {
  included('included', '見積内'),
  excluded('excluded', '対象外'),
  separate('separate', '別途'),
  optional('optional', 'オプション'),
  unknown('unknown', '不明'),
  notApplicable('not_applicable', '該当なし');

  final String code;
  final String labelJa;
  const InclusionStatus(this.code, this.labelJa);

  static InclusionStatus fromCode(String code) => InclusionStatus.values
      .firstWhere((e) => e.code == code, orElse: () => InclusionStatus.unknown);
}

enum ProjectStatus {
  draft('draft', '下書き'),
  collectingQuotes('collecting_quotes', '見積収集中'),
  needsReview('needs_review', '要確認'),
  comparing('comparing', '比較中'),
  clarifying('clarifying', '確認中'),
  decided('decided', '決定済み'),
  archived('archived', 'アーカイブ');

  final String code;
  final String labelJa;
  const ProjectStatus(this.code, this.labelJa);

  static ProjectStatus fromCode(String code) => ProjectStatus.values.firstWhere(
    (e) => e.code == code,
    orElse: () => ProjectStatus.draft,
  );
}

enum QuestionStatus {
  open('open'),
  resolved('resolved');

  final String code;
  const QuestionStatus(this.code);

  static QuestionStatus fromCode(String code) => QuestionStatus.values
      .firstWhere((e) => e.code == code, orElse: () => QuestionStatus.open);
}

class CategoryDefinition {
  final String id;
  final int displayOrder;
  final String nameJa;
  final bool quantityExpected;
  final bool specificationExpected;

  const CategoryDefinition(
    this.id,
    this.displayOrder,
    this.nameJa,
    this.quantityExpected,
    this.specificationExpected,
  );
}

class RawQuoteLineItem {
  final String rawLabel;
  final String categoryId;
  final int? amountYen;
  final InclusionStatus inclusionStatus;
  final double? quantity;
  final String? unit;
  final String? specification;
  final String? note;

  const RawQuoteLineItem({
    required this.rawLabel,
    required this.categoryId,
    this.amountYen,
    this.inclusionStatus = InclusionStatus.unknown,
    this.quantity,
    this.unit,
    this.specification,
    this.note,
  });
}

class RawQuoteData {
  final String contractorName;
  final int? totalAmountYen;
  final List<RawQuoteLineItem> lineItems;
  final String extractedText;
  final String sourcePath;
  final int createdAtEpochMillis;

  const RawQuoteData({
    required this.contractorName,
    this.totalAmountYen,
    this.lineItems = const [],
    required this.extractedText,
    required this.sourcePath,
    required this.createdAtEpochMillis,
  });

  RawQuoteData copyWith({
    String? contractorName,
    int? totalAmountYen,
    List<RawQuoteLineItem>? lineItems,
    String? extractedText,
    String? sourcePath,
    int? createdAtEpochMillis,
  }) {
    return RawQuoteData(
      contractorName: contractorName ?? this.contractorName,
      totalAmountYen: totalAmountYen ?? this.totalAmountYen,
      lineItems: lineItems ?? this.lineItems,
      extractedText: extractedText ?? this.extractedText,
      sourcePath: sourcePath ?? this.sourcePath,
      createdAtEpochMillis: createdAtEpochMillis ?? this.createdAtEpochMillis,
    );
  }

  ContractorQuote toContractorQuote({String? id}) {
    // OCR完了時刻はミリ秒精度のため、短時間に複数保存しても衝突しないIDを生成する。
    final quoteId = id ?? 'quote-${DateTime.now().microsecondsSinceEpoch}';
    return ContractorQuote(
      id: quoteId,
      contractorName: contractorName,
      totalAmountYen: totalAmountYen,
      // 元ファイルの絶対パスは端末のユーザー名や保存場所を含むため、
      // 見積データへ保存しない。OCRの確認状態はsourcePathのハッシュで別管理する。
      note: 'OCR取込',
      createdAtEpochMillis: createdAtEpochMillis,
      lineItems: [
        for (var index = 0; index < lineItems.length; index++)
          QuoteLineItem(
            id: '$quoteId-line-${index + 1}',
            categoryId: lineItems[index].categoryId,
            rawLabel: lineItems[index].rawLabel,
            amountYen: lineItems[index].amountYen,
            inclusionStatus: lineItems[index].inclusionStatus,
            quantity: lineItems[index].quantity,
            unit: lineItems[index].unit,
            specification: lineItems[index].specification,
            note: lineItems[index].note,
            sortOrder: index + 1,
          ),
      ],
    );
  }
}

class QuoteLineItem {
  final String id;
  final String categoryId;
  final String rawLabel;
  final int? amountYen;
  final InclusionStatus inclusionStatus;
  final double? quantity;
  final String? unit;
  final String? specification;
  final String? note;
  final int sortOrder;

  const QuoteLineItem({
    required this.id,
    required this.categoryId,
    required this.rawLabel,
    this.amountYen,
    this.inclusionStatus = InclusionStatus.unknown,
    this.quantity,
    this.unit,
    this.specification,
    this.note,
    this.sortOrder = 0,
  });

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) => QuoteLineItem(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String,
    rawLabel: json['rawLabel'] as String,
    amountYen: json['amountYen'] as int?,
    inclusionStatus: InclusionStatus.fromCode(
      json['inclusionStatus'] as String? ?? 'unknown',
    ),
    quantity: (json['quantity'] as num?)?.toDouble(),
    unit: json['unit'] as String?,
    specification: json['specification'] as String?,
    note: json['note'] as String?,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );
}

class ContractorQuote {
  final String id;
  final String contractorName;
  final int? totalAmountYen;
  final String? note;
  final int createdAtEpochMillis;
  final List<QuoteLineItem> lineItems;

  const ContractorQuote({
    required this.id,
    required this.contractorName,
    this.totalAmountYen,
    this.note,
    required this.createdAtEpochMillis,
    this.lineItems = const [],
  });

  factory ContractorQuote.fromJson(Map<String, dynamic> json) =>
      ContractorQuote(
        id: json['id'] as String,
        contractorName: json['contractorName'] as String,
        totalAmountYen: json['totalAmountYen'] as int?,
        note: json['note'] as String?,
        createdAtEpochMillis: json['createdAtEpochMillis'] as int,
        lineItems:
            (json['lineItems'] as List<dynamic>?)
                ?.map((e) => QuoteLineItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class Project {
  final String id;
  final String name;
  final ProjectStatus status;
  final int createdAtEpochMillis;
  final int updatedAtEpochMillis;
  final List<ContractorQuote> quotes;

  const Project({
    required this.id,
    required this.name,
    required this.status,
    required this.createdAtEpochMillis,
    required this.updatedAtEpochMillis,
    this.quotes = const [],
  });

  factory Project.fromJson(Map<String, dynamic> json) => Project(
    id: json['id'] as String,
    name: json['name'] as String,
    status: ProjectStatus.fromCode(json['status'] as String? ?? 'draft'),
    createdAtEpochMillis: json['createdAtEpochMillis'] as int,
    updatedAtEpochMillis: json['updatedAtEpochMillis'] as int,
    quotes:
        (json['quotes'] as List<dynamic>?)
            ?.map((e) => ContractorQuote.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
  );

  Project copyWith({
    String? name,
    ProjectStatus? status,
    int? updatedAtEpochMillis,
    List<ContractorQuote>? quotes,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      status: status ?? this.status,
      createdAtEpochMillis: createdAtEpochMillis,
      updatedAtEpochMillis: updatedAtEpochMillis ?? this.updatedAtEpochMillis,
      quotes: quotes ?? this.quotes,
    );
  }
}

class NormalizedLine {
  final CategoryDefinition category;
  final InclusionStatus inclusionStatus;
  final int? amountYen;
  final double? quantity;
  final String? unit;
  final String? specification;
  final List<String> sourceLineItemIds;
  final List<String> uncertaintyReasons;

  const NormalizedLine({
    required this.category,
    required this.inclusionStatus,
    this.amountYen,
    this.quantity,
    this.unit,
    this.specification,
    this.sourceLineItemIds = const [],
    this.uncertaintyReasons = const [],
  });
}

class NormalizedQuote {
  final String quoteId;
  final String contractorName;
  final int? totalAmountYen;
  final List<NormalizedLine> lines;

  const NormalizedQuote({
    required this.quoteId,
    required this.contractorName,
    this.totalAmountYen,
    this.lines = const [],
  });
}

class ClarificationQuestion {
  final String id;
  final String projectId;
  final String? quoteId;
  final String? contractorName;
  final String? categoryId;
  final String templateKey;
  final String questionText;
  final QuestionStatus status;
  final int createdAtEpochMillis;

  const ClarificationQuestion({
    required this.id,
    required this.projectId,
    this.quoteId,
    this.contractorName,
    this.categoryId,
    required this.templateKey,
    required this.questionText,
    this.status = QuestionStatus.open,
    required this.createdAtEpochMillis,
  });
}

class QuoteSnapshot {
  final String quoteId;
  final String contractorName;
  final int? totalAmountYen;
  final int includedCategoryCount;
  final List<String> separateCategoryNames;
  final List<String> optionalCategoryNames;
  final List<String> unknownCategoryNames;
  final int uncertaintyCount;

  const QuoteSnapshot({
    required this.quoteId,
    required this.contractorName,
    this.totalAmountYen,
    required this.includedCategoryCount,
    required this.separateCategoryNames,
    required this.optionalCategoryNames,
    required this.unknownCategoryNames,
    required this.uncertaintyCount,
  });
}

class ComparisonCell {
  final String quoteId;
  final String contractorName;
  final InclusionStatus inclusionStatus;
  final int? amountYen;
  final double? quantity;
  final String? unit;
  final String? specification;
  final List<String> uncertaintyReasons;

  const ComparisonCell({
    required this.quoteId,
    required this.contractorName,
    required this.inclusionStatus,
    this.amountYen,
    this.quantity,
    this.unit,
    this.specification,
    this.uncertaintyReasons = const [],
  });
}

class CategoryComparison {
  final CategoryDefinition category;
  final List<ComparisonCell> cells;

  const CategoryComparison({required this.category, required this.cells});
}

class ComparisonReport {
  final String projectId;
  final String projectName;
  final List<QuoteSnapshot> quoteSnapshots;
  final List<CategoryComparison> categoryComparisons;
  final List<String> summaryLines;
  final List<ClarificationQuestion> clarificationQuestions;
  final bool isHistorical;

  const ComparisonReport({
    required this.projectId,
    required this.projectName,
    required this.quoteSnapshots,
    required this.categoryComparisons,
    required this.summaryLines,
    required this.clarificationQuestions,
    this.isHistorical = false,
  });

  ComparisonReport copyWithHistorical() {
    return ComparisonReport(
      projectId: projectId,
      projectName: projectName,
      quoteSnapshots: quoteSnapshots,
      categoryComparisons: categoryComparisons,
      summaryLines: summaryLines,
      clarificationQuestions: clarificationQuestions,
      isHistorical: true,
    );
  }
}
