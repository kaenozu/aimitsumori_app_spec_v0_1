/// ファイルパス: test/comparison_sharing_test.dart
/// 比較画面の共有形式選択テスト
library;

import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('share button offers PDF, image, CSV and text formats', (
    tester,
  ) async {
    final project = createSampleComparisonProject();
    final repository = ProjectRepository(
      databaseService: MockDatabaseService(initialProjects: [project]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ComparisonScreen(
          project: project,
          repository: repository,
          adService: MockAdMobService(adFree: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Platform share channels are not invoked; this test verifies the chooser UI.
    await tester.tap(find.byTooltip('共有'));
    await tester.pumpAndSettle();

    expect(find.text('PDF'), findsOneWidget);
    expect(find.text('画像'), findsOneWidget);
    expect(find.text('CSV'), findsOneWidget);
    expect(find.text('テキスト'), findsOneWidget);
  });
}
