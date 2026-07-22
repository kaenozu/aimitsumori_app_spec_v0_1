import 'package:aimitsumori_app/main.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/repositories/project_requirement_repository.dart';
import 'package:aimitsumori_app/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('empty home offers a sample comparison as the first action', (
    tester,
  ) async {
    final database = MockDatabaseService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: ProjectRepository(databaseService: database),
          requirementRepository: ProjectRequirementRepository(
            databaseService: database,
          ),
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('サンプル比較を試す'), findsOneWidget);
  });

  testWidgets('project search filters by project and contractor name', (
    tester,
  ) async {
    final database = MockDatabaseService(
      initialProjects: [
        createTestProject(id: 'garden', name: '庭まわり改修'),
        createTestProject(
          id: 'parking',
          name: '駐車場拡張',
          quotes: [createTestContractorQuote(contractorName: '熊谷建設')],
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: ProjectRepository(databaseService: database),
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('project-search-field')),
      '庭',
    );
    await tester.pump();

    expect(find.text('庭まわり改修'), findsOneWidget);
    expect(find.text('駐車場拡張'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('project-search-field')),
      '熊谷',
    );
    await tester.pump();

    expect(find.text('庭まわり改修'), findsNothing);
    expect(find.text('駐車場拡張'), findsOneWidget);
  });

  testWidgets('swipe-to-delete confirms and removes the project', (
    tester,
  ) async {
    final project = createTestProject(id: 'delete-me', name: '削除対象案件');
    final database = MockDatabaseService(initialProjects: [project]);

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          repository: ProjectRepository(databaseService: database),
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('project-dismiss-delete-me')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('案件を削除しますか？'), findsOneWidget);
    expect(find.text('「削除対象案件」の見積と比較結果も削除されます。'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, '削除'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('project-card-delete-me')), findsNothing);
    expect(await database.getProject(project.id), isNull);
  });

  testWidgets('dark mode toggle updates the theme and persists the setting', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_completed': true,
      'dark_mode_enabled': false,
    });
    final database = MockDatabaseService();

    await tester.pumpWidget(
      AimitsumoriApp(
        repository: ProjectRepository(databaseService: database),
        adService: MockAdMobService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('メニュー'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('設定'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('privacy-summary-button')));
    await tester.pumpAndSettle();
    expect(find.text('データとプライバシー'), findsNWidgets(2));
    expect(find.textContaining('案件、見積、OCR結果、確認状態は端末内に保存されます。'), findsOneWidget);
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byKey(const ValueKey('dark-mode-switch')),
    );
    expect(switchTile.value, isFalse);

    await tester.tap(find.byKey(const ValueKey('dark-mode-switch')));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.dark);

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('dark_mode_enabled'), isTrue);
  });
}
