import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('late rewarded onAdLoaded callback is disposed before ad.show', () {
    final sourceFile = File('lib/services/ad_service.dart');
    expect(sourceFile.existsSync(), isTrue);

    final source = sourceFile.readAsStringSync();
    final rewardedCallback = source.indexOf(
      'rewardedAdLoadCallback: RewardedAdLoadCallback(',
    );
    final onAdLoaded = source.indexOf('onAdLoaded: (ad) {', rewardedCallback);
    final completedGuard = source.indexOf(
      'if (completer.isCompleted) {',
      onAdLoaded,
    );
    final dispose = source.indexOf('ad.dispose();', completedGuard);
    final earlyReturn = source.indexOf('return;', dispose);
    final show = source.indexOf('ad.show(', onAdLoaded);

    expect(rewardedCallback, greaterThanOrEqualTo(0));
    expect(onAdLoaded, greaterThan(rewardedCallback));
    expect(completedGuard, greaterThan(onAdLoaded));
    expect(dispose, greaterThan(completedGuard));
    expect(earlyReturn, greaterThan(dispose));
    expect(show, greaterThan(earlyReturn));
  });
}
