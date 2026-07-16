/// ファイルパス: lib/repositories/project_repository.dart
/// UI層からSQLite実装を隠す案件リポジトリ
library;

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/database_service.dart';

class ProjectRepository {
  ProjectRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  static final ProjectRepository instance = ProjectRepository();

  final DatabaseService _databaseService;

  Future<List<Project>> getProjects() => _run(
        operation: '案件の読み込み',
        action: _databaseService.getProjects,
      );

  Future<Project?> getProject(String projectId) => _run(
        operation: '案件の読み込み',
        action: () => _databaseService.getProject(projectId),
      );

  Future<void> saveProject(Project project) => _run(
        operation: '案件の保存',
        action: () => _databaseService.saveProject(project),
      );

  Future<void> updateProject(Project project) => _run(
        operation: '案件の更新',
        action: () => _databaseService.updateProject(project),
      );

  Future<void> deleteProject(String projectId) => _run(
        operation: '案件の削除',
        action: () => _databaseService.deleteProject(projectId),
      );

  Future<void> saveQuote(String projectId, ContractorQuote quote) => _run(
        operation: '見積の保存',
        action: () => _databaseService.saveQuote(projectId, quote),
      );

  Future<void> saveComparisonResult(ComparisonReport report) => _run(
        operation: '比較結果の保存',
        action: () => _databaseService.saveComparisonResult(report),
      );

  Future<ComparisonReport?> loadComparisonResult(String projectId) => _run(
        operation: '比較結果の読み込み',
        action: () => _databaseService.loadComparisonResult(projectId),
      );

  Future<T> _run<T>({
    required String operation,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on ProjectRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('$operation failed: $error\n$stackTrace');
      throw ProjectRepositoryException(operation, error);
    }
  }
}

class ProjectRepositoryException implements Exception {
  const ProjectRepositoryException(this.operation, this.cause);

  final String operation;
  final Object cause;

  @override
  String toString() => '$operationに失敗しました。入力内容を確認して、もう一度お試しください。';
}
