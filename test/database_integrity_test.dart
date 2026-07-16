import 'package:aimitsumori_app/models.dart';
import 'package:aimitsumori_app/quote_revision_models.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/repositories/project_requirement_repository.dart';
import 'package:aimitsumori_app/requirements_models.dart';
import 'package:aimitsumori_app/services/database_service.dart';
import 'package:aimitsumori_app/services/quote_revision_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Database database;
  late DatabaseService databaseService;

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
  });

  tearDown(() async {
    await databaseService.close();
  });

  Project project({List<ContractorQuote> quotes = const []}) => Project(
        id: 'project-1',
        name: '外構工事',
        status: ProjectStatus.draft,
        createdAtEpochMillis: 1,
        updatedAtEpochMillis: 1,
        quotes: quotes,
      );

  ContractorQuote quote(String id) => ContractorQuote(
        id: id,
        contractorName: 'A社',
        totalAmountYen: 100000,
        createdAtEpochMillis: 2,
        lineItems: [
          QuoteLineItem(
            id: '$id-line-1',
            categoryId: 'drainage',
            rawLabel: '排水工事',
            amountYen: 100000,
            inclusionStatus: InclusionStatus.included,
            quantity: 10,
            unit: 'm',
          ),
        ],
      );

  test('updating a project preserves requirements and revision history', () async {
    await databaseService.saveProject(project(quotes: [quote('quote-1')]));
    final requirementRepository = ProjectRequirementRepository(
      databaseService: databaseService,
    );
    await requirementRepository.saveRequirements('project-1', const [
      ProjectRequirement(
        categoryId: 'drainage',
        priority: RequirementPriority.required,
      ),
    ]);
    final revisionService = QuoteRevisionService(
      databaseService: databaseService,
    );
    await revisionService.recordQuote(
      projectId: 'project-1',
      quote: quote('quote-1'),
      intent: const QuoteImportIntent.newQuote(),
      sourceFileHash: 'source-1',
    );

    await databaseService.updateProject(
      Project(
        id: 'project-1',
        name: '名称変更後',
        status: ProjectStatus.comparing,
        createdAtEpochMillis: 1,
        updatedAtEpochMillis: 3,
        quotes: [quote('quote-1')],
      ),
    );

    final requirements =
        await requirementRepository.getRequirements('project-1');
    final revisions = await revisionService.getProjectRevisions('project-1');
    expect(
      requirements.singleWhere((value) => value.categoryId == 'drainage').priority,
      RequirementPriority.required,
    );
    expect(revisions, hasLength(1));
    expect((await databaseService.getProject('project-1'))?.name, '名称変更後');
  });

  test('quote and revision are rolled back together when revision insert fails',
      () async {
    await databaseService.saveProject(project());
    final repository = ProjectRepository(
      databaseService: databaseService,
      revisionService: QuoteRevisionService(databaseService: databaseService),
    );
    final invalidIntent = QuoteImportIntent.revision(
      parentQuote: quote('parent'),
      quoteGroupId: 'missing-group',
      parentRevisionId: 'missing-revision',
      changeReason: 'invalid',
    );

    await expectLater(
      repository.saveQuote(
        'project-1',
        quote('quote-failed'),
        revisionIntent: invalidIntent,
        sourceFileHash: 'source-failed',
      ),
      throwsA(isA<ProjectRepositoryException>()),
    );

    final loaded = await databaseService.getProject('project-1');
    expect(loaded?.quotes, isEmpty);
    final rows = await database.query('quote_revisions');
    expect(rows, isEmpty);
  });

  test('revision numbers are allocated sequentially inside transactions', () async {
    final firstQuote = quote('quote-1');
    await databaseService.saveProject(project(quotes: [firstQuote]));
    final revisionService = QuoteRevisionService(
      databaseService: databaseService,
    );
    final first = await revisionService.recordQuote(
      projectId: 'project-1',
      quote: firstQuote,
      intent: const QuoteImportIntent.newQuote(),
      sourceFileHash: 'source-1',
    );
    final second = await revisionService.recordQuote(
      projectId: 'project-1',
      quote: quote('quote-2'),
      intent: QuoteImportIntent.revision(
        parentQuote: firstQuote,
        quoteGroupId: first.quoteGroupId,
        parentRevisionId: first.id,
        changeReason: '仕様変更',
      ),
      sourceFileHash: 'source-2',
    );

    expect(first.revisionNumber, 1);
    expect(second.revisionNumber, 2);
    expect(second.parentRevisionId, first.id);
  });
}
