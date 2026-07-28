import 'package:aimitsumori_app/services/id_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IdGenerator.uuidV4', () {
    test('generates a valid UUID v4 format', () {
      final id = IdGenerator.uuidV4();
      final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(pattern.hasMatch(id), isTrue, reason: 'Expected UUID v4 format: $id');
    });

    test('generates unique IDs across multiple calls', () {
      final ids = <String>{
        for (var i = 0; i < 100; i++) IdGenerator.uuidV4(),
      };
      expect(ids.length, 100);
    });

    test('version bits are set to 4', () {
      final id = IdGenerator.uuidV4();
      expect(id[14], '4', reason: 'UUID v4 version bit must be 4');
    });

    test('variant bits are set to 8, 9, a, or b', () {
      final id = IdGenerator.uuidV4();
      final variantChar = id[19];
      expect('89ab'.contains(variantChar), isTrue,
          reason: 'UUID v4 variant bits must be 8, 9, a, or b: $variantChar');
    });
  });

  group('IdGenerator.prefixed', () {
    test('prepends the given prefix followed by a hyphen', () {
      final id = IdGenerator.prefixed('quote');
      expect(id.startsWith('quote-'), isTrue, reason: 'Expected quote- prefix: $id');
    });

    test('the part after prefix is a valid UUID v4', () {
      final id = IdGenerator.prefixed('project');
      final uuidPart = id.substring('project-'.length);
      final pattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(pattern.hasMatch(uuidPart), isTrue, reason: 'Expected UUID v4 after prefix: $uuidPart');
    });
  });
}