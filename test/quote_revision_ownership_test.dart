import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/services/database_service.dart';
import 'package:aimitsumori_app/services/quote_revision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late DatabaseService databaseService;
  late ProjectRepository repository;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    databaseService = DatabaseService.testing(database);
    await databaseService.initializeSchemaForTesting();
    repository = ProjectRepository(
      databaseService: databaseService,
      revisionService: QuoteRevisionService(databaseService: databaseService),
    );
  });

  tearDown(() => databaseService.close());

  Project project(String id) => Project(
    id: id,
    name: id,
    status: ProjectStatus.draft,
    createdAtEpochMillis: 1,
    updatedAtEpochMillis: 1,
  );

  ContractorQuote quote() => const ContractorQuote(
    id: 'shared-quote-id',
    contractorName: 'A社',
    totalAmountYen: 100000,
    createdAtEpochMillis: 1,
  );

  test('a revision quote ID cannot be reused by another project', () async {
    await repository.saveProject(project('project-1'));
    await repository.saveProject(project('project-2'));
    await repository.saveQuote('project-1', quote());

    // 現在見積だけを消し、履歴が残る状態を再現する。
    await database.delete(
      'contractor_quotes',
      where: 'id = ?',
      whereArgs: ['shared-quote-id'],
    );

    await expectLater(
      repository.saveQuote('project-2', quote()),
      throwsA(isA<ProjectRepositoryException>()),
    );

    expect(await database.query('contractor_quotes'), isEmpty);
    final revisions = await database.query('quote_revisions');
    expect(revisions, hasLength(1));
    expect(revisions.single['project_id'], 'project-1');
  });
}
