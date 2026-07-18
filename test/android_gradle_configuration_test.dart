import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android Gradle configuration', () {
    test('AGP 9 and later keep built-in Kotlin enabled', () {
      final settingsFile = File('android/settings.gradle.kts');
      final propertiesFile = File('android/gradle.properties');

      expect(settingsFile.existsSync(), isTrue);
      expect(propertiesFile.existsSync(), isTrue);

      final settings = settingsFile.readAsStringSync();
      final agpVersionMatch = RegExp(
        r'id\("com\.android\.application"\)\s+version\s+"(\d+)(?:\.\d+){1,2}"',
      ).firstMatch(settings);

      expect(
        agpVersionMatch,
        isNotNull,
        reason: 'The Android Gradle Plugin version could not be read.',
      );

      final agpMajor = int.parse(agpVersionMatch!.group(1)!);
      if (agpMajor < 9) {
        return;
      }

      final properties = _readGradleProperties(propertiesFile);
      expect(
        properties['android.builtInKotlin'],
        'true',
        reason:
            'AGP 9+ must compile Kotlin sources through built-in Kotlin. '
            'Disabling it breaks Kotlin-based Flutter plugins such as '
            'file_picker.',
      );
    });
  });
}

Map<String, String> _readGradleProperties(File file) {
  final result = <String, String>{};

  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }

    final separatorIndex = line.indexOf('=');
    if (separatorIndex <= 0) {
      continue;
    }

    result[line.substring(0, separatorIndex).trim()] = line
        .substring(separatorIndex + 1)
        .trim();
  }

  return result;
}
