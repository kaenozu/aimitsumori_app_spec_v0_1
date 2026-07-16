import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  test('deleteAllData removes every project', () async {
    final database = MockDatabaseService(
      initialProjects: [
        createTestProject(id: 'one', name: '案件1'),
        createTestProject(id: 'two', name: '案件2'),
      ],
    );
    final repository = ProjectRepository(databaseService: database);

    await repository.deleteAllData();

    expect(await repository.getProjects(), isEmpty);
  });
}
