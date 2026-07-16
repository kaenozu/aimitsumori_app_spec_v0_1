import 'package:flutter_test/flutter_test.dart';
import 'package:aimitsumori_app/main.dart';

void main() {
  testWidgets('App renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AimitsumoriApp());
    await tester.pumpAndSettle();
    expect(find.text('相見積もり比較'), findsOneWidget);
  });
}
