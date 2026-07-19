import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('empty comparison screen gives one clear next action', (
    WidgetTester tester,
  ) async {
    final project = createTestProject(name: '新築外構工事');
    final repository = ProjectRepository(
      databaseService: MockDatabaseService(initialProjects: [project]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: project,
          repository: repository,
          adService: MockAdMobService(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('まず1社目の見積を入れます'), findsOneWidget);
    expect(find.text('見積書を追加する'), findsOneWidget);
    expect(find.text('3行サマリー'), findsNothing);
  });
}
