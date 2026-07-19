/// ファイルパス: lib/services/database_service.dart
/// 案件、見積、明細、比較結果をSQLiteへ保存するサービス
library;

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../data/category_master.dart';
import '../models.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const _databaseName = 'aimitsumori.db';
  static const _databaseVersion = 1;

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
    );
    _database = opened;
    return opened;
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE projects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE contractor_quotes (
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
      CREATE TABLE line_items (
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
      CREATE TABLE comparison_results (
        project_id TEXT PRIMARY KEY,
        payload_json TEXT NOT NULL,
        saved_at INTEGER NOT NULL,
        FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_quotes_project ON contractor_quotes(project_id)',
    );
    await db.execute('CREATE INDEX idx_items_quote ON line_items(quote_id)');
  }

  Future<List<Project>> getProjects() async {
    final db = await database;
    final rows = await db.query('projects', orderBy: 'updated_at DESC');
    final projects = <Project>[];
    for (final row in rows) {
      final project = await _loadProject(db, row['id'] as String);
      if (project != null) projects.add(project);
    }
    return projects;
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
          lineItems: itemRows.map(_lineItemFromRow).toList(),
        ),
      );
    }

    final row = projectRows.first;
    return Project(
      id: row['id'] as String,
      name: row['name'] as String,
      status: ProjectStatus.fromCode(row['status'] as String),
      createdAtEpochMillis: row['created_at'] as int,
      updatedAtEpochMillis: row['updated_at'] as int,
      quotes: quotes,
    );
  }

  QuoteLineItem _lineItemFromRow(Map<String, Object?> row) {
    return QuoteLineItem(
      id: row['id'] as String,
      categoryId: row['category_id'] as String,
      rawLabel: row['raw_label'] as String,
      amountYen: row['amount_yen'] as int?,
      inclusionStatus: InclusionStatus.fromCode(
        row['inclusion_status'] as String,
      ),
      quantity: (row['quantity'] as num?)?.toDouble(),
      unit: row['unit'] as String?,
      specification: row['specification'] as String?,
      note: row['note'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
    );
  }

  Future<void> saveProject(Project project) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'projects',
        _projectToRow(project),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.delete(
        'contractor_quotes',
        where: 'project_id = ?',
        whereArgs: [project.id],
      );
      for (final quote in project.quotes) {
        await _insertQuote(txn, project.id, quote);
      }
      await txn.delete(
        'comparison_results',
        where: 'project_id = ?',
        whereArgs: [project.id],
      );
    });
  }

  Future<void> updateProject(Project project) async => saveProject(project);

  Future<void> deleteProject(String projectId) async {
    final db = await database;
    await db.delete('projects', where: 'id = ?', whereArgs: [projectId]);
  }

  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      // 要件・改訂履歴のテーブルは遅延作成のため、存在する場合だけ削除する。
      for (final table in [
        'comparison_results',
        'line_items',
        'contractor_quotes',
        'quote_revisions',
        'project_requirements',
        'projects',
      ]) {
        final exists = await txn.query(
          'sqlite_master',
          columns: const ['name'],
          where: 'type = ? AND name = ?',
          whereArgs: ['table', table],
          limit: 1,
        );
        if (exists.isNotEmpty) await txn.delete(table);
      }
    });
  }

  Future<void> saveQuote(String projectId, ContractorQuote quote) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'projects',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [projectId],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw StateError('保存先の案件が見つかりません: $projectId');
      }

      await _insertQuote(txn, projectId, quote);
      await txn.update(
        'projects',
        {
          'status': ProjectStatus.needsReview.code,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'id = ?',
        whereArgs: [projectId],
      );
      await txn.delete(
        'comparison_results',
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
    });
  }

  Future<void> _insertQuote(
    DatabaseExecutor db,
    String projectId,
    ContractorQuote quote,
  ) async {
    await db.insert('contractor_quotes', {
      'id': quote.id,
      'project_id': projectId,
      'contractor_name': quote.contractorName,
      'total_amount_yen': quote.totalAmountYen,
      'note': quote.note,
      'created_at': quote.createdAtEpochMillis,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete('line_items', where: 'quote_id = ?', whereArgs: [quote.id]);
    for (final item in quote.lineItems) {
      await db.insert('line_items', {
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
      }, conflictAlgorithm: ConflictAlgorithm.replace);
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
    await db.insert('comparison_results', {
      'project_id': report.projectId,
      'payload_json': jsonEncode(_reportToJson(report)),
      'saved_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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
        jsonDecode(rows.first['payload_json'] as String)
            as Map<String, dynamic>;
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
    for (final raw
        in json['categoryComparisons'] as List<dynamic>? ?? const []) {
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
        inclusionStatus: InclusionStatus.fromCode(
          json['inclusionStatus'] as String,
        ),
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
