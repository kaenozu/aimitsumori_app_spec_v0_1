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
    expect(script, contains('--dart-define=PURCHASE_VERIFICATION_URL='));
  });

  test('CI release validation builds APK and AAB', () {
    final workflow = File(
      '.github/workflows/flutter_ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('PURCHASE_VERIFICATION_URL:'));
    expect(workflow, contains('--dart-define=PURCHASE_VERIFICATION_URL='));
    expect(workflow, contains('flutter build apk --release --no-pub'));
    expect(workflow, contains('flutter build appbundle --release --no-pub'));
    expect(
      workflow,
      contains('build/app/outputs/bundle/release/app-release.aab'),
    );
    expect(workflow, contains('aimitsumori-release-validation-android'));
  });

  test('production AAB workflow requires signing and product secrets', () {
    final workflow = File(
      '.github/workflows/production_android_aab.yml',
    ).readAsStringSync();

    for (final secret in <String>[
      'ANDROID_KEYSTORE_BASE64',
      'ANDROID_KEYSTORE_PASSWORD',
      'ANDROID_KEY_PASSWORD',
      'ANDROID_KEY_ALIAS',
      'ADMOB_APP_ID',
      'ADMOB_ANDROID_BANNER_ID',
      'ADMOB_ANDROID_REWARDED_ID',
      'REMOVE_ADS_PRODUCT_ID',
      'PURCHASE_VERIFICATION_URL',
    ]) {
      expect(workflow, contains('\${{ secrets.$secret }}'));
    }
    expect(
      workflow,
      contains('./tool/build_android_release.ps1 -Artifact appbundle'),
    );
    expect(workflow, contains('jarsigner -verify -strict'));
    expect(workflow, contains('app-release.aab.sha256'));
  });
}
