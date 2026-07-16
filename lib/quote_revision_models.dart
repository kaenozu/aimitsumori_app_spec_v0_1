/// 見積書の改訂履歴と差分を表すドメインモデル。
library;

import 'models.dart';

class QuoteRevision {
  const QuoteRevision({
    required this.id,
    required this.projectId,
    required this.quoteId,
    required this.contractorName,
    required this.quoteGroupId,
    required this.revisionNumber,
    this.parentRevisionId,
    required this.sourceFileHash,
    required this.importedAt,
    this.changeReason,
    required this.quoteSnapshot,
  });

  final String id;
  final String projectId;
  final String quoteId;
  final String contractorName;
  final String quoteGroupId;
  final int revisionNumber;
  final String? parentRevisionId;
  final String sourceFileHash;
  final int importedAt;
  final String? changeReason;
  final ContractorQuote quoteSnapshot;
}

enum QuoteLineChangeType {
  added,
  removed,
  amount,
  unitPrice,
  quantity,
  unit,
  specification,
  inclusion,
}

class QuoteLineChange {
  const QuoteLineChange({
    required this.type,
    required this.categoryId,
    required this.label,
    this.before,
    this.after,
    this.beforeUnitPriceYen,
    this.afterUnitPriceYen,
  });

  final QuoteLineChangeType type;
  final String categoryId;
  final String label;
  final QuoteLineItem? before;
  final QuoteLineItem? after;
  final double? beforeUnitPriceYen;
  final double? afterUnitPriceYen;
}

class QuoteRevisionDiff {
  const QuoteRevisionDiff({
    required this.before,
    required this.after,
    required this.totalDifferenceYen,
    required this.changes,
  });

  final QuoteRevision before;
  final QuoteRevision after;
  final int? totalDifferenceYen;
  final List<QuoteLineChange> changes;
}

class QuoteImportIntent {
  const QuoteImportIntent._({
    required this.isRevision,
    this.parentQuote,
    this.quoteGroupId,
    this.parentRevisionId,
    this.changeReason,
  });

  const QuoteImportIntent.newQuote() : this._(isRevision: false);

  const QuoteImportIntent.revision({
    required ContractorQuote parentQuote,
    required String quoteGroupId,
    String? parentRevisionId,
    required String changeReason,
  }) : this._(
          isRevision: true,
          parentQuote: parentQuote,
          quoteGroupId: quoteGroupId,
          parentRevisionId: parentRevisionId,
          changeReason: changeReason,
        );

  final bool isRevision;
  final ContractorQuote? parentQuote;
  final String? quoteGroupId;
  final String? parentRevisionId;
  final String? changeReason;
}
