/// ファイルパス: integration_test/app_test.dart
/// オンボーディング、案件比較、OCR導線、pull-to-refreshの統合テスト
library;

import 'package:aimitsumori_app/main.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'app launches, loads sample data, shows three projects and compares A/B/C',
    (tester) async {
      final database = MockDatabaseService(
        initialProjects: [
          createTestProject(
            id: 'project-parking',
            name: '駐車場拡張',
            updatedAtEpochMillis: 1700000002000,
          ),
          createTestProject(
            id: 'project-garden',
            name: '庭まわり改修',
            updatedAtEpochMillis: 1700000001000,
          ),
        ],
      );
      final repository = ProjectRepository(databaseService: database);
      final adService = MockAdMobService();

      await tester.pumpWidget(
        AimitsumoriApp(
          repository: repository,
          adService: adService,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('見積書の「違い」を見つける'), findsOneWidget);
      expect(find.text('サンプルデータで試す'), findsOneWidget);

      await tester.tap(find.text('サンプルデータで試す'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('project-card-sample-exterior-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-card-project-parking')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('project-card-project-garden')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('project-card-sample-exterior-001')),
      );
      await tester.pumpAndSettle();

      expect(find.text('比較'), findsOneWidget);
      expect(find.text('新築外構 3社相見積もり'), findsOneWidget);
      expect(find.text('A社'), findsOneWidget);
      expect(find.text('B社'), findsOneWidget);
      expect(find.text('C社'), findsOneWidget);
      expect(find.textContaining('2,530,000円'), findsWidgets);
      expect(find.textContaining('3,450,000円'), findsWidgets);
      expect(find.textContaining('2,785,000円'), findsWidgets);
    },
  );

  testWidgets('OCR screen exposes PDF, camera and save controls', (tester) async {
    final project = createSampleComparisonProject();
    final database = MockDatabaseService(initialProjects: [project]);
    final repository = ProjectRepository(databaseService: database);

    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: project,
          repository: repository,
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('見積を追加'));
    await tester.pumpAndSettle();

    expect(find.text('見積書を取り込む'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quote-pdf-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quote-photo-button')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('quote-save-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('quote-photo-button')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('quote-camera-option')),
      findsOneWidget,
    );
    expect(find.text('カメラで撮影'), findsOneWidget);
  });

  testWidgets('comparison pull-to-refresh reloads the project', (tester) async {
    final project = createSampleComparisonProject();
    final database = MockDatabaseService(initialProjects: [project]);
    final repository = ProjectRepository(databaseService: database);

    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: project,
          repository: repository,
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final callsBeforeRefresh = database.getProjectCallCount;
    await tester.drag(
      find.byType(RefreshIndicator),
      const Offset(0, 360),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(database.getProjectCallCount, greaterThan(callsBeforeRefresh));
    expect(find.text('新築外構 3社相見積もり'), findsOneWidget);
  });
}
