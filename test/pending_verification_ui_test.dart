import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  Future<void> pumpComparison(
    WidgetTester tester,
    MockAdMobService adService,
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
          adService: adService,
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('検証待ちの購入がある間は比較画面に非破壊の案内バナーを出す', (tester) async {
    await pumpComparison(
      tester,
      MockAdMobService(adFree: false, pendingVerificationCount: 1),
    );

    expect(find.text('購入を確認中です'), findsOneWidget);
    // バナーは案内のみで操作を妨げない。
    expect(find.text('まず1社目の見積を入れます'), findsOneWidget);
    expect(find.text('見積書を追加する'), findsOneWidget);
  });

  testWidgets('要確認に昇格した購入はサポート案内付きで表示する', (tester) async {
    await pumpComparison(
      tester,
      MockAdMobService(adFree: false, purchaseNeedsConfirmation: true),
    );

    expect(find.text('要確認：購入の確認が未完了です'), findsOneWidget);
    expect(find.text('まず1社目の見積を入れます'), findsOneWidget);
  });

  testWidgets('検証待ちがなければバナーは出さない', (tester) async {
    await pumpComparison(tester, MockAdMobService());

    expect(find.text('購入を確認中です'), findsNothing);
    expect(find.text('要確認：購入の確認が未完了です'), findsNothing);
  });
}
