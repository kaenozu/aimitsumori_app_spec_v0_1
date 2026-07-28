/// 案件要望をSQLiteへ保存する専用リポジトリ。
library;

import '../utils/app_logger.dart';

import 'package:sqflite/sqflite.dart';

import '../data/category_master.dart';
import '../requirements_models.dart';
import '../services/database_service.dart';
import '../services/value_normalizer.dart';

class ProjectRequirementRepository {
  ProjectRequirementRepository({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  static final ProjectRequirementRepository instance =
      ProjectRequirementRepository();

  final DatabaseService _databaseService;

  Future<List<ProjectRequirement>> getRequirements(String projectId) => _run(
    operation: '要望チェックリストの読み込み',
    action: () async {
      final db = await _databaseService.database;
      final rows = await db.query(
        'project_requirements',
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      final byCategory = <String, ProjectRequirement>{
        for (final row in rows) row['category_id'] as String: _fromRow(row),
      };
      return [
        for (final category in CategoryMaster.categories)
          byCategory[category.id] ??
              ProjectRequirement(categoryId: category.id),
      ];
    },
  );

  Future<void> saveRequirements(
    String projectId,
    List<ProjectRequirement> requirements,
  ) => _run(
    operation: '要望チェックリストの保存',
    action: () async {
      final normalized = _normalize(requirements);
      final db = await _databaseService.database;
      await db.transaction((transaction) async {
        final project = await transaction.query(
          'projects',
          columns: const ['id'],
          where: 'id = ?',
          whereArgs: [projectId],
          limit: 1,
        );
        if (project.isEmpty) {
          throw StateError('保存先の案件が見つかりません: $projectId');
        }
        await transaction.delete(
          'project_requirements',
          where: 'project_id = ?',
          whereArgs: [projectId],
        );
        for (final requirement in normalized) {
          await transaction.insert(
            'project_requirements',
            _toRow(projectId, requirement),
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      });
    },
  );

  List<ProjectRequirement> _normalize(List<ProjectRequirement> requirements) {
    final byCategory = <String, ProjectRequirement>{};
    for (final requirement in requirements) {
      if (CategoryMaster.find(requirement.categoryId) == null) {
        throw ArgumentError.value(
          requirement.categoryId,
          'categoryId',
          'Unknown category',
        );
      }
      if (byCategory.containsKey(requirement.categoryId)) {
        throw ArgumentError('同じカテゴリの要望が重複しています。');
      }
      final quantity = requirement.expectedQuantity;
      if (quantity != null && (!quantity.isFinite || quantity <= 0)) {
        throw ArgumentError.value(
          quantity,
          'expectedQuantity',
          'Quantity must be finite and greater than zero',
        );
      }
      final unit = UnitNormalizer.normalize(requirement.expectedUnit);
      final specification = _nullable(requirement.desiredSpecification);
      final note = _nullable(requirement.note);
      if ((specification?.length ?? 0) > 500 || (note?.length ?? 0) > 500) {
        throw ArgumentError('希望仕様とメモは500文字以内で入力してください。');
      }
      byCategory[requirement.categoryId] = ProjectRequirement(
        categoryId: requirement.categoryId,
        priority: requirement.priority,
        expectedQuantity: quantity,
        expectedUnit: unit,
        desiredSpecification: specification,
        note: note,
      );
    }
    return [
      for (final category in CategoryMaster.categories)
        byCategory[category.id] ?? ProjectRequirement(categoryId: category.id),
    ];
  }

  ProjectRequirement _fromRow(Map<String, Object?> row) => ProjectRequirement(
    categoryId: row['category_id'] as String,
    priority: RequirementPriority.fromCode(row['priority'] as String),
    expectedQuantity: (row['expected_quantity'] as num?)?.toDouble(),
    expectedUnit: row['expected_unit'] as String?,
    desiredSpecification: row['desired_specification'] as String?,
    note: row['note'] as String?,
  );

  Map<String, Object?> _toRow(
    String projectId,
    ProjectRequirement requirement,
  ) => {
    'project_id': projectId,
    'category_id': requirement.categoryId,
    'priority': requirement.priority.code,
    'expected_quantity': requirement.expectedQuantity,
    'expected_unit': requirement.expectedUnit,
    'desired_specification': requirement.desiredSpecification,
    'note': requirement.note,
  };

  String? _nullable(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<T> _run<T>({
    required String operation,
    required Future<T> Function() action,
  }) async {
    try {
      return await action();
    } on ProjectRequirementRepositoryException {
      rethrow;
    } catch (error, stackTrace) {
      AppLogger.debug('$operation failed: $error\n$stackTrace');
      throw ProjectRequirementRepositoryException(operation, error);
    }
  }
}

class ProjectRequirementRepositoryException implements Exception {
  const ProjectRequirementRepositoryException(this.operation, this.cause);

  final String operation;
  final Object cause;

  @override
  String toString() => '$operationに失敗しました。もう一度お試しください。';
}
