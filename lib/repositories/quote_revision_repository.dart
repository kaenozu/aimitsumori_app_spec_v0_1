/// UI層から見積改訂履歴のSQLite実装を隠すリポジトリ。
library;

import '../models.dart';
import '../quote_revision_models.dart';
import '../services/quote_revision_service.dart';

class QuoteRevisionRepository {
  QuoteRevisionRepository({QuoteRevisionService? service})
      : _service = service ?? QuoteRevisionService.instance;

  static final QuoteRevisionRepository instance = QuoteRevisionRepository();

  final QuoteRevisionService _service;

  Future<void> ensureInitialRevisions(Project project) {
    return _service.ensureInitialRevisions(
      projectId: project.id,
      quotes: project.quotes,
    );
  }

  Future<List<QuoteRevision>> getProjectRevisions(String projectId) {
    return _service.getProjectRevisions(projectId);
  }
}
