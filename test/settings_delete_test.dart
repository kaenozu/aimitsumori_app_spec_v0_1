import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/settings_screen.dart';
import 'package:aimitsumori_app/services/ocr_review_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('deleting all data also clears OCR review state', (tester) async {
    SharedPreferences.setMockInitialValues({
      'ocr_review_states_v1_1234': '{"line":"confirmed"}',
      'dark_mode_enabled': true,
    });
    final preferences = await SharedPreferences.getInstance();
    final repository = ProjectRepository(
      databaseService: MockDatabaseService(
        initialProjects: [createTestProject(id: 'delete-me')],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          repository: repository,
          reviewStore: OcrReviewStore(preferences: preferences),
          darkModeEnabled: true,
          onDarkModeChanged: (_) {},
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('delete-all-data-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('削除を続ける'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('完全に削除'));
    await tester.pumpAndSettle();

    expect(await repository.getProjects(), isEmpty);
    expect(preferences.getString('ocr_review_states_v1_1234'), isNull);
    expect(preferences.getBool('dark_mode_enabled'), isTrue);
  });
}
