/// ファイルパス: lib/services/database_service.dart
/// 案件、見積、明細、比較結果をSQLiteへ保存するサービス
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/category_master.dart';
import '../models.dart';

typedef DatabaseTransactionCallback = Future<void> Function(
  DatabaseExecutor transaction,
);

class DatabaseService {
  DatabaseService._();

  @visibleForTesting
  DatabaseService.testing(Database database) : _database = database;

  static final DatabaseService instance = DatabaseService._();
  static const _databaseName = 'aimitsumori.db';
  static const _databaseVersion = 3;

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final databasePath = p.join(await getDatabasesPath(), _databaseName);
    final opened = await openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createSchema,
      onUpgrade: _upgradeSchema,
    );
    _database = opened;
    return opened;
  }

  @visibleForTesting
  Future<void> initializeSchemaForTesting() async {
    final db = await database;
    await _createSchema(db, _databaseVersion);
  }

  Future<void> _createSchema(Database db, int version) async {
    await _createCoreSchema(db);
    await _createRequirementsSchema(db);
    await _createRevisionSchema(db);
  }

  Future<void> _upgradeSchema(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) await _createRequirementsSchema(db);
    if (oldVersion < 3) await _createRevisionSchema(db);
  }

  Future<void> _createCoreSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS contractor_quotes (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        contractor_name TEXT NOT NULL,
        total_amount_yen INTEGER,
        note TEXT,
        created_at INTEGER NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS line_items (
        id TEXT PRIMARY KEY,
        quote_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        raw_label TEXT NOT NULL,
        amount_yen INTEGER,
        inclusion_status TEXT NOT NULL,
        quantity REAL,
        unit TEXT,
        specification TEXT,
        note TEXT,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY(quote_id) REFERENCES contractor_quotes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS comparison_results (
        project_id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        saved_at INTEGER NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quotes_project '
      'ON contractor_quotes(project_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_items_quote ON line_items(quote_id)',
    );
  }

  Future<void> _createRequirementsSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_requirements (
        project_id TEXT NOT NULL,
        category_id TEXT NOT NULL,
        priority TEXT NOT NULL,
        expected_quantity REAL,
        expected_unit TEXT,
        desired_specification TEXT,
        note TEXT,
        PRIMARY KEY(project_id, category_id),
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_requirements_project '
      'ON project_requirements(project_id)',
    );
  }

  Future<void> _createRevisionSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS quote_revisions (
        id TEXT PRIMARY KEY,
        project_id TEXT NOT NULL,
        quote_id TEXT NOT NULL,
        contractor_name TEXT NOT NULL,
        quote_group_id TEXT NOT NULL,
        revision_number INTEGER NOT NULL,
        parent_revision_id TEXT,
        source_file_hash TEXT NOT NULL,
        imported_at INTEGER NOT NULL,
        change_reason TEXT,
        quote_snapshot_json TEXT NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_quote_revisions_group_number '
      'ON quote_revisions(quote_group_id, revision_number)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quote_revisions_project '
      'ON quote_revisions(project_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_quote_revisions_quote '
      'ON quote_revisions(quote_id)',
    );
  }

  Future<List<Project>> getProjects() async {
    final db = await database;
    final projectRows = await db.query('projects', orderBy: 'updated_at DESC');
    if (projectRows.isEmpty) return const [];

    final quoteRows = await db.query('contractor_quotes', orderBy: 'created_at ASC');
    final itemRows = await db.query('line_items', orderBy: 'sort_order ASC');
    final itemsByQuote = <String, List<QuoteLineItem>>{};
    for (final row in itemRows) {
      final quoteId = row['quote_id'] as String;
      itemsByQuote.putIfAbsent(quoteId, () => []).add(_lineItemFromRow(row));
    }
    final quotesByProject = <String, List<ContractorQuote>>{};
    for (final row in quoteRows) {
      final quoteId = row['id'] as String;
      final projectId = row['project_id'] as String;
      quotesByProject.putIfAbsent(projectId, () => []).add(
            ContractorQuote(
              id: quoteId,
              contractorName: row['contractor_name'] as String,
              totalAmountYen: row['total_amount_yen'] as int?,
              note: row['note'] as String?,
              createdAtEpochMillis: row['created_at'] as int,
              lineItems: itemsByQuote[quoteId] ?? const [],
            ),
          );
    }
    return [
      for (final row in projectRows)
        _projectFromRow(
          row,
          quotesByProject[row['id'] as String] ?? const [],
        ),
    ];
  }

  Future<Project?> getProject(String projectId) async {
    final db = await database;
    return _loadProject(db, projectId);
  }

  Future<Project?> _loadProject(DatabaseExecutor db, String projectId) async {
    final projectRows = await db.query(
      'projects',
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (projectRows.isEmpty) return null;

    final quoteRows = await db.query(
      'contractor_quotes',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'created_at ASC',
    );
    final quotes = <ContractorQuote>[];
    for (final quoteRow in quoteRows) {
      final quoteId = quoteRow['id'] as String;
      final itemRows = await db.query(
        'line_items',
        where: 'quote_id = ?',
        whereArgs: [quoteId],
        orderBy: 'sort_order ASC',
      );
      quotes.add(
        ContractorQuote(
          id: quoteId,
          contractorName: quoteRow['contractor_name'] as String,
          totalAmountYen: quoteRow['total_amount_yen'] as int?,
          note: quoteRow['note'] as String?,
          createdAtEpochMillis: quoteRow['created_at'] as int,
          lineItems: itemRows.map(_lineItemFromRow).toList(growable: false),
        ),
      );
    }
    return _projectFromRow(projectRows.first, quotes);
  }

  Project _projectFromRow(
    Map<String, Object?> row,
    List<ContractorQuote> quotes,
  ) =>
      Project(
        id: row['id'] as String,
        name: row['name'] as String,
        status: ProjectStatus.fromCode(row['status'] as String),
        createdAtEpochMillis: row['created_at'] as int,
        updatedAtEpochMillis: row['updated_at'] as int,
        quotes: quotes,
      );

  QuoteLineItem _lineItemFromRow(Map<String, Object?> row) {
    return QuoteLineItem(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      rawLabel: row['raw_label'] as String,
      amountYen: row['amount_yen'] as int?,
      inclusionStatus: InclusionStatus.fromCode(row['inclusion_status'] as String),
      quantity: (row['quantity'] as num?)?.toDouble(),
      unit: row['unit'] as String?,
      specification: row['specification'] as String?,
      note: row['note'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  Future<void> saveProject(Project project) async {
    final db = await database;
    await db.transaction((transaction) async {
      await _upsertProject(transaction, project);
      await transaction.delete(
        'contractor_quotes',
        where: 'project_id = ?',
        whereArgs: [project.id],
      );
      for (final quote in project.quotes) {
        await _upsertQuote(transaction, project.id, quote);
      }
      await transaction.delete(
        'comparison_results',
        where: 'project_id = ?',
        whereArgs: [project.id],
      );
    });
  }

  Future<void> updateProject(Project project) async => saveProject(project);

  Future<void> _upsertProject(
    DatabaseExecutor db,
    Project project,
  ) async {
    final row = _projectToRow(project);
    final updated = await db.update(
      'projects',
      row,
      where: 'id = ?',
      whereArgs: [project.id],
    );
    if (updated == 0) {
      await db.insert(
        'projects',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<void> deleteProject(String projectId) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((transaction) async {
      await transaction.delete('projects');
    });
  }

  Future<void> saveQuote(
    String projectId,
    ContractorQuote quote, {
    DatabaseTransactionCallback? afterQuoteSaved,
  }) async {
    final db = await database;
    await db.transaction((transaction) async {
      await saveQuoteInTransaction(transaction, projectId, quote);
      await afterQuoteSaved?.call(transaction);
    });
  }

  @visibleForTesting
  Future<void> saveQuoteInTransaction(
    DatabaseExecutor transaction,
    String projectId,
    ContractorQuote quote,
  ) async {
    final existing = await transaction.query(
      'projects',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (existing.isEmpty) {
      throw StateError('保存先の案件が見つかりません: $projectId');
    }

    await _upsertQuote(transaction, projectId, quote);
    await transaction.update(
      'projects',
      {
        'status': ProjectStatus.needsReview.code,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [projectId],
    );
    await transaction.delete(
      'comparison_results',
      where: 'project_id = ?',
      whereArgs: [projectId],
    );
  }

  Future<void> _upsertQuote(
    DatabaseExecutor db,
    String projectId,
    ContractorQuote quote,
  ) async {
    final row = <String, Object?>{
      'id': quote.id,
      'project_id': projectId,
      'contractor_name': quote.contractorName,
      'total_amount_yen': quote.totalAmountYen,
      'note': quote.note,
      'created_at': quote.createdAtEpochMillis,
    };
    final updated = await db.update(
      'contractor_quotes',
      row,
      where: 'id = ?',
      whereArgs: [quote.id],
    );
    if (updated == 0) {
      await db.insert(
        'contractor_quotes',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }

    await db.delete('line_items', where: 'quote_id = ?', whereArgs: [quote.id]);
    final ids = <String>{};
    for (final item in quote.lineItems) {
      if (!ids.add(item.id)) {
        throw StateError('同じ明細IDが重複しています: ${item.id}');
      }
      await db.insert(
        'line_items',
        {
          'id': item.id,
          'quote_id': quote.id,
          'category_id': item.categoryId,
          'raw_label': item.rawLabel,
          'amount_yen': item.amountYen,
          'inclusion_status': item.inclusionStatus.code,
          'quantity': item.quantity,
          'unit': item.unit,
          'specification': item.specification,
          'note': item.note,
          'sort_order': item.sortOrder,
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Map<String, Object?> _projectToRow(Project project) => {
        'id': project.id,
        'name': project.name,
        'status': project.status.code,
        'created_at': project.createdAtEpochMillis,
        'updated_at': project.updatedAtEpochMillis,
      };

  Future<void> saveComparisonResult(ComparisonReport report) async {
    final db = await database;
    final row = <String, Object?>{
      'project_id': report.projectId,
      'payload_json': jsonEncode(_reportToJson(report)),
      'saved_at': DateTime.now().millisecondsSinceEpoch,
    };
    final updated = await db.update(
      'comparison_results',
      row,
      where: 'project_id = ?',
      whereArgs: [report.projectId],
    );
    if (updated == 0) {
      await db.insert(
        'comparison_results',
        row,
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
    }
  }

  Future<ComparisonReport?> loadComparisonResult(String projectId) async {
    final db = await database;
    final rows = await db.query(
      'comparison_results',
      columns: ['payload_json'],
      where: 'project_id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final payload =
        jsonDecode(rows.first['payload_json'] as String) as Map<String, dynamic>;
    return _reportFromJson(payload);
  }

  Map<String, Object?> _reportToJson(ComparisonReport report) => {
        'projectId': report.projectId,
        'projectName': report.projectName,
        'summaryLines': report.summaryLines,
        'quoteSnapshots': [
          for (final snapshot in report.quoteSnapshots)
            {
              'quoteId': snapshot.quoteId,
              'contractorName': snapshot.contractorName,
              'totalAmountYen': snapshot.totalAmountYen,
              'includedCategoryCount': snapshot.includedCategoryCount,
              'separateCategoryNames': snapshot.separateCategoryNames,
              'optionalCategoryNames': snapshot.optionalCategoryNames,
              'unknownCategoryNames': snapshot.unknownCategoryNames,
              'uncertaintyCount': snapshot.uncertaintyCount,
            },
        ],
        'categoryComparisons': [
          for (final comparison in report.categoryComparisons)
            {
              'categoryId': comparison.category.id,
              'cells': [
                for (final cell in comparison.cells)
                  {
                    'quoteId': cell.quoteId,
                    'contractorName': cell.contractorName,
                    'inclusionStatus': cell.inclusionStatus.code,
                    'amountYen': cell.amountYen,
                    'quantity': cell.quantity,
                    'unit': cell.unit,
                    'specification': cell.specification,
                    'uncertaintyReasons': cell.uncertaintyReasons,
                  },
              ],
            },
        ],
        'clarificationQuestions': [
          for (final question in report.clarificationQuestions)
            {
              'id': question.id,
              'projectId': question.projectId,
              'quoteId': question.quoteId,
              'contractorName': question.contractorName,
              'categoryId': question.categoryId,
              'templateKey': question.templateKey,
              'questionText': question.questionText,
              'status': question.status.code,
              'createdAtEpochMillis': question.createdAtEpochMillis,
            },
        ],
      };

  ComparisonReport _reportFromJson(Map<String, dynamic> json) {
    final comparisons = <CategoryComparison>[];
    for (final raw in json['categoryComparisons'] as List<dynamic>? ?? const []) {
      final value = Map<String, dynamic>.from(raw as Map);
      final category = CategoryMaster.find(value['categoryId'] as String);
      if (category == null) continue;
      comparisons.add(
        CategoryComparison(
          category: category,
          cells: [
            for (final cellRaw in value['cells'] as List<dynamic>? ?? const [])
              _comparisonCellFromJson(
                Map<String, dynamic>.from(cellRaw as Map),
              ),
          ],
        ),
      );
    }

    return ComparisonReport(
      projectId: json['projectId'] as String,
      projectName: json['projectName'] as String,
      summaryLines: List<String>.from(
        json['summaryLines'] as List<dynamic>? ?? const [],
      ),
      quoteSnapshots: [
        for (final raw in json['quoteSnapshots'] as List<dynamic>? ?? const [])
          _quoteSnapshotFromJson(Map<String, dynamic>.from(raw as Map)),
      ],
      categoryComparisons: comparisons,
      clarificationQuestions: [
        for (final raw
            in json['clarificationQuestions'] as List<dynamic>? ?? const [])
          _questionFromJson(Map<String, dynamic>.from(raw as Map)),
      ],
    );
  }

  QuoteSnapshot _quoteSnapshotFromJson(Map<String, dynamic> json) =>
      QuoteSnapshot(
        quoteId: json['quoteId'] as String,
        contractorName: json['contractorName'] as String,
        totalAmountYen: json['totalAmountYen'] as int?,
        includedCategoryCount: json['includedCategoryCount'] as int,
        separateCategoryNames: List<String>.from(
          json['separateCategoryNames'] as List<dynamic>? ?? const [],
        ),
        optionalCategoryNames: List<String>.from(
          json['optionalCategoryNames'] as List<dynamic>? ?? const [],
        ),
        unknownCategoryNames: List<String>.from(
          json['unknownCategoryNames'] as List<dynamic>? ?? const [],
        ),
        uncertaintyCount: json['uncertaintyCount'] as int,
      );

  ComparisonCell _comparisonCellFromJson(Map<String, dynamic> json) =>
      ComparisonCell(
        quoteId: json['quoteId'] as String,
        contractorName: json['contractorName'] as String,
        inclusionStatus:
            InclusionStatus.fromCode(json['inclusionStatus'] as String),
        amountYen: json['amountYen'] as int?,
        quantity: (json['quantity'] as num?)?.toDouble(),
        unit: json['unit'] as String?,
        specification: json['specification'] as String?,
        uncertaintyReasons: List<String>.from(
          json['uncertaintyReasons'] as List<dynamic>? ?? const [],
        ),
      );

  ClarificationQuestion _questionFromJson(Map<String, dynamic> json) =>
      ClarificationQuestion(
        id: json['id'] as String,
        projectId: json['projectId'] as String,
        quoteId: json['quoteId'] as String?,
        contractorName: json['contractorName'] as String?,
        categoryId: json['categoryId'] as String?,
        templateKey: json['templateKey'] as String,
        questionText: json['questionText'] as String,
        status: QuestionStatus.fromCode(json['status'] as String),
        createdAtEpochMillis: json['createdAtEpochMillis'] as int,
      );

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
