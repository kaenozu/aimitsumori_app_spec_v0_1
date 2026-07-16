/// 見積取り込み前の新規・改訂意図を構築する。
library;

import '../models.dart';
import '../quote_revision_models.dart';
import 'quote_revision_service.dart';

class QuoteRevisionImportCoordinator {
  QuoteRevisionImportCoordinator({QuoteRevisionService? service})
      : service = service ?? QuoteRevisionService.instance;

  final QuoteRevisionService service;

  QuoteImportIntent newQuote() => const QuoteImportIntent.newQuote();

  Future<QuoteImportIntent> revision({
    required String projectId,
    required ContractorQuote parentQuote,
    required String changeReason,
  }) async {
    var groupId = await service.groupIdForQuote(parentQuote.id);
    var parentRevisionId = await service.revisionIdForQuote(parentQuote.id);
    if (groupId == null) {
      final initial = await service.recordQuote(
        projectId: projectId,
        quote: parentQuote,
        intent: const QuoteImportIntent.newQuote(),
      );
      groupId = initial.quoteGroupId;
      parentRevisionId = initial.id;
    }
    return QuoteImportIntent.revision(
      parentQuote: parentQuote,
      quoteGroupId: groupId,
      parentRevisionId: parentRevisionId,
      changeReason: changeReason,
    );
  }

  QuoteImportIntent revisionFromHistory({
    required QuoteRevision parentRevision,
    required String changeReason,
  }) {
    return QuoteImportIntent.revision(
      parentQuote: parentRevision.quoteSnapshot,
      quoteGroupId: parentRevision.quoteGroupId,
      parentRevisionId: parentRevision.id,
      changeReason: changeReason,
    );
  }
}
