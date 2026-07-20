/// ファイルパス: lib/repositories/estimate_repository.dart
/// 見積の永続化実装から利用側を分離するための最小インターフェース。
library;

import '../models.dart';

abstract interface class EstimateRepository {
  Future<List<ContractorQuote>> findAll(String projectId);

  Future<void> save(String projectId, ContractorQuote estimate);

  Future<void> delete(String projectId, String estimateId);
}
