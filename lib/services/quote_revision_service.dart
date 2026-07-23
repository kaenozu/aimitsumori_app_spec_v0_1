/// 見積改訂履歴のSQLite永続化を管理する。
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../models.dart';
import '../quote_revision_models.dart';
import 'database_service.dart';

class QuoteRevisionService {
  QuoteRevisionService({DatabaseService? databaseService})
    : _databaseService = databaseService ?? DatabaseService.instance;

  static final QuoteRevisionService instance = QuoteRevisionService();

  final DatabaseService _databaseService;

  Future<QuoteRevision> recordQuote({
    required String projectId,
    required ContractorQuote quote,
    QuoteImportIntent intent = const QuoteImportIntent.newQuote(),
    String? sourceFileHash,
  }) async {
    final db = await _databaseService.database;
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
    final projectRows = await transaction.query(
      'projects',
      columns: const ['id'],
      where: 'id = ?',
      whereArgs: [projectId],
      limit: 1,
    );
    if (projectRows.isEmpty) {
      throw StateError('改訂履歴の保存先案件が見つかりません: $projectId');
    }

    final existingRows = await transaction.query(
      'quote_revisions',
      where: 'quote_id = ?',
      whereArgs: [quote.id],
      limit: 1,
    );
    if (existingRows.isNotEmpty) {
      final existing = _fromRow(existingRows.first);
      if (existing.projectId != projectId) {
        throw StateError('同じ見積IDが別案件の改訂履歴で使用されています: ${quote.id}');
      }
      if (intent.isRevision &&
          intent.quoteGroupId != null &&
          existing.quoteGroupId != intent.quoteGroupId) {
        throw StateError('見積IDと改訂グループの組み合わせが一致しません。');
      }
      return existing;
    }

    final groupId = intent.isRevision
        ? _requiredGroupId(intent)
        : 'group-$projectId-${_stableHash('${quote.id}|${quote.contractorName}')}';

    final groupRows = await transaction.query(
      'quote_revisions',
      columns: const ['id', 'project_id', 'revision_number'],
      where: 'quote_group_id = ?',
      whereArgs: [groupId],
      orderBy: 'revision_number DESC',
    );
    if (groupRows.any((row) => row['project_id'] != projectId)) {
      throw StateError('改訂グループが別案件に属しています: $groupId');
    }

    final previousRevisionNumber = groupRows.isEmpty
        ? 0
        : groupRows.first['revision_number'] as int;
    final revisionNumber = previousRevisionNumber + 1;

    String? parentRevisionId;
    if (intent.isRevision) {
      final requestedParentId = intent.parentRevisionId;
      if (requestedParentId != null) {
        final parentRows = await transaction.query(
          'quote_revisions',
          columns: const ['id', 'project_id', 'quote_group_id'],
          where: 'id = ?',
          whereArgs: [requestedParentId],
          limit: 1,
        );
        if (parentRows.isEmpty ||
            parentRows.first['project_id'] != projectId ||
            parentRows.first['quote_group_id'] != groupId) {
          throw StateError('指定された親改訂版が同じ案件・グループに存在しません。');
        }
        parentRevisionId = requestedParentId;
      } else if (groupRows.isNotEmpty) {
        parentRevisionId = groupRows.first['id'] as String;
      } else {
        throw StateError('改訂版として保存するには親となる第1版が必要です。');
      }
    }

    final normalizedHash = sourceFileHash?.trim();
    final revision = QuoteRevision(
      id: 'revision-$groupId-$revisionNumber',
      projectId: projectId,
      quoteId: quote.id,
      contractorName: quote.contractorName,
      quoteGroupId: groupId,
      revisionNumber: revisionNumber,
      parentRevisionId: parentRevisionId,
      sourceFileHash: normalizedHash == null || normalizedHash.isEmpty
          ? _quoteHash(quote)
          : normalizedHash,
      importedAt: DateTime.now().millisecondsSinceEpoch,
      changeReason: intent.changeReason?.trim().isEmpty == true
          ? null
          : intent.changeReason?.trim(),
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
    await db.transaction((transaction) async {
      final rows = await transaction.query(
        'quote_revisions',
        columns: const ['quote_id'],
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
    final rows = await db.query(
      'quote_revisions',
      columns: const ['quote_group_id'],
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['quote_group_id'] as String;
  }

  Future<String?> revisionIdForQuote(String quoteId) async {
    final db = await _databaseService.database;
    final rows = await db.query(
      'quote_revisions',
      columns: const ['id'],
      where: 'quote_id = ?',
      whereArgs: [quoteId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['id'] as String;
  }

  String _requiredGroupId(QuoteImportIntent intent) {
    final groupId = intent.quoteGroupId?.trim();
    if (groupId == null || groupId.isEmpty) {
      throw StateError('改訂版として保存するには改訂グループIDが必要です。');
    }
    return groupId;
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

  String _stableHash(String value) =>
      sha256.convert(utf8.encode(value)).toString().substring(0, 24);
}
