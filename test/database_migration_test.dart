import 'dart:io';

import 'package:aimitsumori_app/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory temporaryDirectory;
  late String databasePath;

  setUp(() async {
    await DatabaseService.instance.close();
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'aimitsumori-db-migration-',
    );
    await databaseFactory.setDatabasesPath(temporaryDirectory.path);
    databasePath = p.join(temporaryDirectory.path, 'aimitsumori.db');

    final legacyDatabase = await openDatabase(
      databasePath,
      version: 1,
      onConfigure: (database) => database.execute('PRAGMA foreign_keys = ON'),
      onCreate: _createVersion1Schema,
    );
    await _seedVersion1Data(legacyDatabase);
    expect(await legacyDatabase.getVersion(), 1);
    await legacyDatabase.close();
  });

  tearDown(() async {
    await DatabaseService.instance.close();
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('opening a v1 database migrates it to v4 without data loss', () async {
    final database = await DatabaseService.instance.database;

    expect(await database.getVersion(), 4);
    expect(
      (await database.rawQuery('PRAGMA foreign_keys')).single.values.single,
      1,
    );

    final project = (await database.query('projects')).single;
    expect(project['id'], 'project-v1');
    expect(project['name'], '移行前案件');

    final quote = (await database.query('contractor_quotes')).single;
    expect(quote['id'], 'quote-v1');
    expect(quote['total_amount_yen'], 1200000);

    final lineItem = (await database.query('line_items')).single;
    expect(lineItem['raw_label'], '基礎工事');
    expect(lineItem['sort_order'], 0);

    final comparison = (await database.query('comparison_results')).single;
    expect(comparison['payload_json'], '{"source":"v1"}');

    final tableRows = await database.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    );
    final tableNames = tableRows
        .map((row) => row['name'])
        .whereType<String>()
        .toSet();
    expect(
      tableNames,
      containsAll(<String>{'project_requirements', 'quote_revisions'}),
    );

    final revisionIndexes = await database.rawQuery(
      'PRAGMA index_list(quote_revisions)',
    );
    final quoteRevisionIndex = revisionIndexes.singleWhere(
      (row) => row['name'] == 'idx_quote_revisions_quote',
    );
    expect(quoteRevisionIndex['unique'], 1);

    await database.insert('project_requirements', <String, Object?>{
      'project_id': 'project-v1',
      'category_id': 'foundation',
      'priority': 'required',
    });

    await database.insert('quote_revisions', <String, Object?>{
      'id': 'revision-1',
      'project_id': 'project-v1',
      'quote_id': 'quote-v1',
      'contractor_name': 'A社',
      'quote_group_id': 'group-1',
      'revision_number': 1,
      'source_file_hash': 'hash-1',
      'imported_at': 200,
      'quote_snapshot_json': '{}',
    });

    expect(
      database.insert('quote_revisions', <String, Object?>{
        'id': 'revision-2',
        'project_id': 'project-v1',
        'quote_id': 'quote-v1',
        'contractor_name': 'A社',
        'quote_group_id': 'group-2',
        'revision_number': 1,
        'source_file_hash': 'hash-2',
        'imported_at': 300,
        'quote_snapshot_json': '{}',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}

Future<void> _createVersion1Schema(Database database, int version) async {
  await database.execute('''
    CREATE TABLE projects (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      status TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    )
  ''');
  await database.execute('''
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
  await database.execute('''
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
  await database.execute('''
    CREATE TABLE comparison_results (
      project_id TEXT PRIMARY KEY,
      payload_json TEXT NOT NULL,
      saved_at INTEGER NOT NULL,
      FOREIGN KEY(project_id) REFERENCES projects(id) ON DELETE CASCADE
    )
  ''');
  await database.execute(
    'CREATE INDEX idx_quotes_project ON contractor_quotes(project_id)',
  );
  await database.execute(
    'CREATE INDEX idx_items_quote ON line_items(quote_id)',
  );
}

Future<void> _seedVersion1Data(Database database) async {
  await database.insert('projects', <String, Object?>{
    'id': 'project-v1',
    'name': '移行前案件',
    'status': 'comparing',
    'created_at': 100,
    'updated_at': 101,
  });
  await database.insert('contractor_quotes', <String, Object?>{
    'id': 'quote-v1',
    'project_id': 'project-v1',
    'contractor_name': 'A社',
    'total_amount_yen': 1200000,
    'note': '移行前見積',
    'created_at': 110,
  });
  await database.insert('line_items', <String, Object?>{
    'id': 'line-v1',
    'quote_id': 'quote-v1',
    'category_id': 'foundation',
    'raw_label': '基礎工事',
    'amount_yen': 1200000,
    'inclusion_status': 'included',
    'quantity': 1.0,
    'unit': '式',
    'specification': '標準仕様',
    'note': null,
    'sort_order': 0,
  });
  await database.insert('comparison_results', <String, Object?>{
    'project_id': 'project-v1',
    'payload_json': '{"source":"v1"}',
    'saved_at': 120,
  });
}
