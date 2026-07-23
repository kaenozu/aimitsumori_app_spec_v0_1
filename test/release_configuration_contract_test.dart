import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release build requires purchase verification URL', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('PURCHASE_VERIFICATION_URL'));
    expect(
      gradle,
      contains('PURCHASE_VERIFICATION_URL is required for release builds.'),
    );
    expect(gradle, contains('must be an HTTPS URL'));
  });

  test('release PowerShell passes purchase verification URL to Dart', () {
    final script = File('tool/build_android_release.ps1').readAsStringSync();

    expect(script, contains("'PURCHASE_VERIFICATION_URL'"));
    expect(script, contains('PURCHASE_VERIFICATION_URL must be an HTTPS URL.'));
    expect(
      script,
      contains('--dart-define=PURCHASE_VERIFICATION_URL='),
    );
  });

  test('CI release validation provides purchase verification URL', () {
    final workflow = File(
      '.github/workflows/flutter_ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('PURCHASE_VERIFICATION_URL:'));
    expect(
      workflow,
      contains('--dart-define=PURCHASE_VERIFICATION_URL='),
    );
  });
}
