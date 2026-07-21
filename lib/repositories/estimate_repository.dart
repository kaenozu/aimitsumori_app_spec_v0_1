/// ファイルパス: lib/repositories/estimate_repository.dart
/// 見積の永続化実装から利用側を分離するための最小インターフェース。
library;

import '../models.dart';

abstract interface class EstimateRepository {
  /// 指定案件に保存されている見積をすべて取得する。
  Future<List<ContractorQuote>> findAll(String projectId);

  /// 指定案件へ見積を新規保存または更新する。
  Future<void> save(String projectId, ContractorQuote quote);

  /// 指定案件から見積を削除する。
  Future<void> delete(String projectId, String quoteId);
}
