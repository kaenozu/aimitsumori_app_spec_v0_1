import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('repository validator separates config and applied state', () {
    final script = File(
      'tool/configure_github_repository.ps1',
    ).readAsStringSync();

    expect(script, contains('[switch]\$ValidateConfigOnly'));
    expect(script, contains('[switch]\$ValidateAppliedProtection'));
    expect(script, contains('GitHub reports main as unprotected.'));
    expect(script, contains("Applied ruleset '"));
    expect(
      script,
      contains(
        'Repository protection was not applied; do not treat local JSON validation as protection success.',
      ),
    );
  });

  test('CI explicitly checks GitHub applied protection', () {
    final workflow = File(
      '.github/workflows/repository-protection.yml',
    ).readAsStringSync();

    expect(workflow, contains('Validate checked-in ruleset contract'));
    expect(workflow, contains('-ValidateConfigOnly'));
    expect(workflow, contains('Validate GitHub applied protection'));
    expect(workflow, contains('-ValidateAppliedProtection'));
    expect(workflow, contains('GH_TOKEN: \${{ github.token }}'));
  });
}
