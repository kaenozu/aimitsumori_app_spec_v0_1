import 'package:aimitsumori_app/widgets/pending_verification_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('PendingVerificationBanner', () {
    testWidgets('検証待ちの間は自動再試行の案内を出す', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PendingVerificationBanner(
            needsConfirmation: false,
            pendingCount: 1,
          ),
        ),
      );

      expect(find.text('購入を確認中です'), findsOneWidget);
      expect(find.text('要確認：購入の確認が未完了です'), findsNothing);
    });

    testWidgets('要確認状態ではサポート案内を強調して出す', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PendingVerificationBanner(
            needsConfirmation: true,
            pendingCount: 1,
          ),
        ),
      );

      expect(find.text('要確認：購入の確認が未完了です'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('対象がなければ何も表示しない', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const PendingVerificationBanner(
            needsConfirmation: false,
            pendingCount: 0,
          ),
        ),
      );

      expect(find.byType(Card), findsNothing);
      expect(find.text('購入を確認中です'), findsNothing);
    });
  });
}
