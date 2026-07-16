import 'package:aimitsumori_app/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App renders onboarding on first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AimitsumoriApp());
    await tester.pumpAndSettle();

    expect(find.text('見積書の「違い」を見つける'), findsOneWidget);
    expect(find.text('サンプルデータで試す'), findsOneWidget);
    expect(find.text('空の状態から始める'), findsOneWidget);
  });
}
