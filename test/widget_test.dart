import 'package:aimitsumori_app/main.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('App renders onboarding on first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final database = MockDatabaseService();
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
    expect(find.text('空の状態から始める'), findsOneWidget);
    expect(database.getProjectsCallCount, 0);
  });
}
