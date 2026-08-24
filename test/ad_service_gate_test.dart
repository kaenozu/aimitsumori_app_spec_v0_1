import 'package:aimitsumori_app/services/ad_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RewardedAdLoadGate', () {
    test('初期状態では広告表示を許可する', () {
      final gate = RewardedAdLoadGate();

      expect(gate.canPresent, isTrue);
    });

    test('確定後は二度と広告表示を許可しない', () {
      final gate = RewardedAdLoadGate();

      expect(gate.settle(RewardedAdOutcome.unavailable), isTrue);
      expect(gate.canPresent, isFalse);
      expect(gate.settle(RewardedAdOutcome.rewarded), isFalse);
      expect(gate.canPresent, isFalse);
    });

    test('outcomeは最初に確定した値を維持する', () async {
      final gate = RewardedAdLoadGate();

      gate.settle(RewardedAdOutcome.unavailable);
      gate.settle(RewardedAdOutcome.rewarded);

      expect(await gate.outcome, RewardedAdOutcome.unavailable);
    });

    test('タイムアウト前に報酬確定した場合はその値を返す', () async {
      final gate = RewardedAdLoadGate();

      expect(gate.settle(RewardedAdOutcome.rewarded), isTrue);
      expect(gate.canPresent, isFalse);
      expect(
        gate.settle(RewardedAdOutcome.unavailable),
        isFalse,
        reason: 'タイムアウトは確定済みの結果を上書きできない',
      );

      expect(await gate.outcome, RewardedAdOutcome.rewarded);
    });
  });
}
