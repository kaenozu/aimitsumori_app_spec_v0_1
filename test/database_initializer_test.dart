import 'package:flutter_test/flutter_test.dart';

import 'package:aimitsumori_app/services/database_initializer.dart';
import 'package:aimitsumori_app/services/database_service.dart';

void main() {
  test(
    'initializes the database implementation before opening SQLite',
    () async {
      await initializeDatabase();

      final projects = await DatabaseService.instance.getProjects();
      expect(projects, isA<List>());
      await DatabaseService.instance.close();
    },
  );
}
