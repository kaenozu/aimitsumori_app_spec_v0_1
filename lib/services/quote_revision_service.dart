/// 見積改訂履歴のSQLite永続化を管理する。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';
import '../quote_revision_models.dart';
import 'database_service.dart';
import 'id_generator.dart';

class QuoteRevisionService {
  QuoteRevisionService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  static final QuoteRevisionService instance = QuoteRevisionService();

  final DatabaseService _databaseService;
  Future<void>? _schemaFuture;

  Future<void> _ensureSchema(Database db) {
    return _schemaFuture ??= _createSchema(db);
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
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
      'CREATE UNIQUE INDEX IF NOT EXISTS '
      'idx_quote_revisions_group_number '
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

  Future<QuoteRevision> recordQuote({
    required String projectId,
    required ContractorQuote quote,
    QuoteImportIntent intent = const QuoteImportIntent.newQuote(),
    String? sourceFileHash,
  }) async {
    final db = await _databaseService.database;
    await _ensureSchema(db);
    return db.transaction(
      (transaction) => recordQuoteInTransaction(
        transaction,
        projectId: projectId,
        quote: quote,
        intent: intent,
        sourceFileHash: sourceFileHash,
      ),
    );
  }

  Future<QuoteRevision> recordQuoteInTransaction(
    DatabaseExecutor transaction, {
    required String projectId,
    required ContractorQuote quote,
    QuoteImportIntent intent = const QuoteImportIntent.newQuote(),
    String? sourceFileHash,
  }) async {
    final resolvedSourceHash = sourceFileHash ?? _quoteHash(quote);
    final now = DateTime.now().millisecondsSinceEpoch;
    final groupId = intent.isRevision
        ? intent.quoteGroupId!
        : IdGenerator.prefixed('group');

    if (intent.isRevision) {
      final groupRows = await transaction.query(
        'quote_revisions',
        columns: ['id'],
        where: 'quote_group_id = ? AND project_id = ?',
        whereArgs: [groupId, projectId],
        limit: 1,
      );
      if (groupRows.isEmpty) {
        throw StateError('改訂元の見積グループが見つかりません。');
      }
    }

    final previousRows = await transaction.query(
      'quote_revisions',
      where: 'quote_group_id = ?',
      whereArgs: [groupId],
      orderBy: 'revision_number DESC',
      limit: 1,
    );
    final latestRevisionId = previousRows.isEmpty
        ? null
        : previousRows.first['id'] as String;
    final revisionNumber = previousRows.isEmpty
        ? 1
        : (previousRows.first['revision_number'] as int) + 1;
    final parentRevisionId = intent.isRevision
        ? intent.parentRevisionId ?? latestRevisionId
        : null;

    if (parentRevisionId != null) {
      final parentRows = await transaction.query(
        'quote_revisions',
        columns: ['id'],
        where: 'id = ? AND quote_group_id = ?',
        whereArgs: [parentRevisionId, groupId],
        limit: 1,
      );
      if (parentRows.isEmpty) {
        throw StateError('指定された親版が同じ見積グループに存在しません。');
      }
    }

    final revision = QuoteRevision(
      id: IdGenerator.prefixed('revision'),
      projectId: projectId,
      quoteId: quote.id,
      contractorName: quote.contractorName,
      quoteGroupId: groupId,
      revisionNumber: revisionNumber,
      parentRevisionId: parentRevisionId,
      sourceFileHash: resolvedSourceHash,
      importedAt: now,
      changeReason: intent.changeReason,
      quoteSnapshot: quote,
    );
    await transaction.insert(
      'quote_revisions',
      _toRow(revision),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return revision;
  }

  Future<void> ensureInitialRevisions({
    required String projectId,
    required List<ContractorQuote> quotes,
  }) async {
    if (quotes.isEmpty) return;
    final db = await _databaseService.database;
    await _ensureSchema(db);
    await db.transaction((transaction) async {
      final rows = await transaction.query(
        'quote_revisions',
        columns: ['quote_id'],
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      final existingQuoteIds = {
        for (final row in rows) row['quote_id'] as String,
      };
      for (final quote in quotes) {
        if (existingQuoteIds.contains(quote.id)) continue;
        await recordQuoteInTransaction(
          transaction,
          projectId: projectId,
          quote: quote,
          sourceFileHash: _quoteHash(quote),
        );
      }
    });
  }

  Future<List<QuoteRevision>> getProjectRevisions(String projectId) async {
    final db = await _databaseService.database;
    await _ensureSchema(db);
    final rows = await db.query(
      'quote_revisions',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'contractor_name ASC, quote_group_id ASC, revision_number ASC',
    );
    return rows.map(_fromRow).toList(growable: false);
  }

  Future<String?> groupIdForQuote(String quoteId) async {
    final db = await _databaseService.database;
    await _ensureSchema(db);
    final rows = await db.query(
      'quote_revisions',
      columns: ['quote_group_id'],
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      orderBy: 'revision_number DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['quote_group_id'] as String;
  }

  Future<String?> revisionIdForQuote(String quoteId) async {
    final db = await _databaseService.database;
    await _ensureSchema(db);
    final rows = await db.query(
      'quote_revisions',
      columns: ['id'],
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      orderBy: 'revision_number DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  Map<String, Object?> _toRow(QuoteRevision revision) => {
    'id': revision.id,
    'project_id': revision.projectId,
    'quote_id': revision.quoteId,
    'contractor_name': revision.contractorName,
    'quote_group_id': revision.quoteGroupId,
    'revision_number': revision.revisionNumber,
    'parent_revision_id': revision.parentRevisionId,
    'source_file_hash': revision.sourceFileHash,
    'imported_at': revision.importedAt,
    'change_reason': revision.changeReason,
    'quote_snapshot_json': jsonEncode(_quoteToJson(revision.quoteSnapshot)),
  };

  QuoteRevision _fromRow(Map<String, Object?> row) => QuoteRevision(
    id: row['id'] as String,
    projectId: row['project_id'] as String,
    quoteId: row['quote_id'] as String,
    contractorName: row['contractor_name'] as String,
    quoteGroupId: row['quote_group_id'] as String,
    revisionNumber: row['revision_number'] as int,
    parentRevisionId: row['parent_revision_id'] as String?,
    sourceFileHash: row['source_file_hash'] as String,
    importedAt: row['imported_at'] as int,
    changeReason: row['change_reason'] as String?,
    quoteSnapshot: _quoteFromJson(
      Map<String, dynamic>.from(
        jsonDecode(row['quote_snapshot_json'] as String) as Map,
      ),
    ),
  );

  Map<String, Object?> _quoteToJson(ContractorQuote quote) => {
    'id': quote.id,
    'contractorName': quote.contractorName,
    'totalAmountYen': quote.totalAmountYen,
    'note': quote.note,
    'createdAtEpochMillis': quote.createdAtEpochMillis,
    'lineItems': [
      for (final item in quote.lineItems)
        {
          'id': item.id,
          'categoryId': item.categoryId,
          'rawLabel': item.rawLabel,
          'amountYen': item.amountYen,
          'inclusionStatus': item.inclusionStatus.code,
          'quantity': item.quantity,
          'unit': item.unit,
          'specification': item.specification,
          'note': item.note,
          'sortOrder': item.sortOrder,
        },
    ],
  };

  ContractorQuote _quoteFromJson(Map<String, dynamic> json) => ContractorQuote(
    id: json['id'] as String,
    contractorName: json['contractorName'] as String,
    totalAmountYen: json['totalAmountYen'] as int?,
    note: json['note'] as String?,
    createdAtEpochMillis: json['createdAtEpochMillis'] as int,
    lineItems: [
      for (final raw in json['lineItems'] as List<dynamic>? ?? const [])
        QuoteLineItem.fromJson(Map<String, dynamic>.from(raw as Map)),
    ],
  );

  String _quoteHash(ContractorQuote quote) =>
      sha256.convert(utf8.encode(jsonEncode(_quoteToJson(quote)))).toString();
}
