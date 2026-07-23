import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late DatabaseService service;

  setUp(() async {
    database = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    service = DatabaseService.testing(database);
    await service.initializeSchemaForTesting();
  });

  tearDown(() => service.close());

  ContractorQuote quote(String id) => ContractorQuote(
    id: id,
    contractorName: 'A社',
    totalAmountYen: 100000,
    createdAtEpochMillis: 2,
    lineItems: [
      QuoteLineItem(
        id: '$id-line-1',
        categoryId: 'concrete',
        rawLabel: '土間コンクリート',
        amountYen: 100000,
        inclusionStatus: InclusionStatus.included,
      ),
    ],
  );

  Project project({
    required ProjectStatus status,
    required List<ContractorQuote> quotes,
    int updatedAt = 1,
  }) => Project(
    id: 'project-1',
    name: '外構工事',
    status: status,
    createdAtEpochMillis: 1,
    updatedAtEpochMillis: updatedAt,
    quotes: quotes,
  );

  test('saveProject preserves the supplied status and timestamp', () async {
    await service.saveProject(
      project(
        status: ProjectStatus.comparing,
        updatedAt: 99,
        quotes: [quote('quote-1')],
      ),
    );

    final loaded = await service.getProject('project-1');

    expect(loaded?.status, ProjectStatus.comparing);
    expect(loaded?.updatedAtEpochMillis, 99);
  });

  test('saveProject removes current quotes omitted from the aggregate', () async {
    await service.saveProject(
      project(
        status: ProjectStatus.needsReview,
        quotes: [quote('quote-1'), quote('quote-2')],
      ),
    );

    await service.saveProject(
      project(
        status: ProjectStatus.comparing,
        updatedAt: 3,
        quotes: [quote('quote-2')],
      ),
    );

    final loaded = await service.getProject('project-1');
    expect(loaded?.quotes.map((value) => value.id), ['quote-2']);
  });
}
