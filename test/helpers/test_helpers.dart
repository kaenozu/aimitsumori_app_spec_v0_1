/// ファイルパス: test/helpers/test_helpers.dart
/// テスト用のインメモリDB・広告モックとドメインモデル生成ヘルパー
library;

import 'package:aimitsumori_app/data/sample_data.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/services/ad_service.dart';
import 'package:aimitsumori_app/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:sqflite/sqflite.dart';

class MockDatabaseService implements DatabaseService {
  MockDatabaseService({List<Project> initialProjects = const []})
    : _projects = List<Project>.from(initialProjects);

  final List<Project> _projects;
  final Map<String, ComparisonReport> _reports = <String, ComparisonReport>{};

  int getProjectsCallCount = 0;
  int getProjectCallCount = 0;
  int saveProjectCallCount = 0;
  int saveComparisonResultCallCount = 0;
  int deleteAllDataCallCount = 0;

  @override
  Future<Database> get database => Future<Database>.error(
    UnsupportedError('MockDatabaseService does not expose a SQLite database.'),
  );

  @override
  Future<List<Project>> getProjects() async {
    getProjectsCallCount += 1;
    return List<Project>.unmodifiable(_projects);
  }

  @override
  Future<Project?> getProject(String projectId) async {
    getProjectCallCount += 1;
    for (final project in _projects) {
      if (project.id == projectId) return project;
    }
    return null;
  }

  @override
  Future<void> saveProject(Project project) async {
    saveProjectCallCount += 1;
    _projects.removeWhere((existing) => existing.id == project.id);
    _projects.insert(0, project);
  }

  @override
  Future<void> updateProject(Project project) async {
    final index = _projects.indexWhere((existing) => existing.id == project.id);
    if (index == -1) {
      _projects.insert(0, project);
    } else {
      _projects[index] = project;
    }
  }

  @override
  Future<void> deleteProject(String projectId) async {
    _projects.removeWhere((project) => project.id == projectId);
    _reports.remove(projectId);
  }

  @override
  Future<void> deleteAllData() async {
    deleteAllDataCallCount += 1;
    _projects.clear();
    _reports.clear();
  }

  @override
  Future<void> saveQuote(String projectId, ContractorQuote quote) async {
    final projectIndex = _projects.indexWhere(
      (project) => project.id == projectId,
    );
    if (projectIndex == -1) {
      throw StateError('保存先の案件が見つかりません: $projectId');
    }

    final project = _projects[projectIndex];
    final quotes = List<ContractorQuote>.from(project.quotes);
    final quoteIndex = quotes.indexWhere((existing) => existing.id == quote.id);
    if (quoteIndex == -1) {
      quotes.add(quote);
    } else {
      quotes[quoteIndex] = quote;
    }

    _projects[projectIndex] = project.copyWith(
      status: ProjectStatus.needsReview,
      updatedAtEpochMillis: project.updatedAtEpochMillis + 1,
      quotes: quotes,
    );
    _reports.remove(projectId);
  }

  @override
  Future<void> saveComparisonResult(ComparisonReport report) async {
    saveComparisonResultCallCount += 1;
    _reports[report.projectId] = report;
  }

  @override
  Future<ComparisonReport?> loadComparisonResult(String projectId) async =>
      _reports[projectId];

  @override
  Future<void> close() async {}
}

class MockAdMobService extends AdService {
  MockAdMobService({super.adFree = true}) : super.testing();

  int bannerRequestCount = 0;
  int rewardedRequestCount = 0;
  int purchaseRequestCount = 0;
  int restoreRequestCount = 0;

  @override
  BannerAd? createBannerAd({
    VoidCallback? onLoaded,
    ValueChanged<LoadAdError>? onFailed,
  }) {
    bannerRequestCount += 1;
    return null;
  }

  @override
  Future<RewardedAdOutcome> showRewardedAd() async {
    rewardedRequestCount += 1;
    return RewardedAdOutcome.rewarded;
  }

  @override
  Future<bool> purchaseRemoveAds() async {
    purchaseRequestCount += 1;
    return true;
  }

  @override
  Future<void> restorePurchases() async {
    restoreRequestCount += 1;
  }
}

Project createTestProject({
  String id = 'project-test-1',
  String name = 'テスト案件',
  ProjectStatus status = ProjectStatus.comparing,
  int createdAtEpochMillis = 1700000000000,
  int? updatedAtEpochMillis,
  List<ContractorQuote> quotes = const [],
}) {
  return Project(
    id: id,
    name: name,
    status: status,
    createdAtEpochMillis: createdAtEpochMillis,
    updatedAtEpochMillis: updatedAtEpochMillis ?? createdAtEpochMillis,
    quotes: quotes,
  );
}

ContractorQuote createTestContractorQuote({
  String id = 'quote-test-1',
  String contractorName = 'テスト業者',
  int? totalAmountYen = 1000000,
  String? note,
  int createdAtEpochMillis = 1700000001000,
  List<QuoteLineItem> lineItems = const [],
}) {
  return ContractorQuote(
    id: id,
    contractorName: contractorName,
    totalAmountYen: totalAmountYen,
    note: note,
    createdAtEpochMillis: createdAtEpochMillis,
    lineItems: lineItems,
  );
}

Project createSampleComparisonProject() => SampleData.project();
