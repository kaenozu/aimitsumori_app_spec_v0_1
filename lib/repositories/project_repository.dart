/// ファイルパス: lib/repositories/project_repository.dart
/// UI層からSQLite実装を隠す案件リポジトリ
library;

import '../models.dart';
import '../services/database_service.dart';

class ProjectRepository {
  ProjectRepository({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService.instance;

  static final ProjectRepository instance = ProjectRepository();

  final DatabaseService _databaseService;

  Future<List<Project>> getProjects() => _databaseService.getProjects();

  Future<Project?> getProject(String projectId) => _databaseService.getProject(projectId);

  Future<void> saveProject(Project project) => _databaseService.saveProject(project);

  Future<void> updateProject(Project project) => _databaseService.updateProject(project);

  Future<void> deleteProject(String projectId) => _databaseService.deleteProject(projectId);

  Future<void> saveQuote(String projectId, ContractorQuote quote) =>
      _databaseService.saveQuote(projectId, quote);

  Future<void> saveComparisonResult(ComparisonReport report) =>
      _databaseService.saveComparisonResult(report);

  Future<ComparisonReport?> loadComparisonResult(String projectId) =>
      _databaseService.loadComparisonResult(projectId);
}
