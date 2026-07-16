/// 見積取り込み前の新規・改訂セッションを設定する。
library;

import '../models.dart';
import '../quote_revision_models.dart';
import 'quote_revision_service.dart';

class QuoteRevisionImportCoordinator {
  QuoteRevisionImportCoordinator({QuoteRevisionService? service})
      : service = service ?? QuoteRevisionService.instance;

  final QuoteRevisionService service;

  void beginNewQuote() {
    QuoteRevisionSession.instance.begin(const QuoteImportIntent.newQuote());
  }

  Future<void> beginRevision({
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
    QuoteRevisionSession.instance.begin(
      QuoteImportIntent.revision(
        parentQuote: parentQuote,
        quoteGroupId: groupId,
        parentRevisionId: parentRevisionId,
        changeReason: changeReason,
      ),
    );
  }

  void beginRevisionFromHistory({
    required QuoteRevision parentRevision,
    required String changeReason,
  }) {
    QuoteRevisionSession.instance.begin(
      QuoteImportIntent.revision(
        parentQuote: parentRevision.quoteSnapshot,
        quoteGroupId: parentRevision.quoteGroupId,
        parentRevisionId: parentRevision.id,
        changeReason: changeReason,
      ),
    );
  }

  void cancel() => QuoteRevisionSession.instance.clear();
}
