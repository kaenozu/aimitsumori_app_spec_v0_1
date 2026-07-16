import 'dart:io';

import 'package:aimitsumori_app/repositories/project_repository.dart';
import 'package:aimitsumori_app/screens/comparison_screen.dart';
import 'package:aimitsumori_app/widgets/accessibility_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_helpers.dart';

void main() {
  testWidgets('accessible icon button exposes TalkBack label and 48px target', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccessibleIconButton(
            label: '比較結果を共有',
            icon: const Icon(Icons.share_outlined),
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('比較結果を共有'), findsOneWidget);
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));

    await tester.tap(find.bySemanticsLabel('比較結果を共有'));
    expect(pressed, isTrue);
    semantics.dispose();
  });

  testWidgets('status badge communicates icon, text and semantic status', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AccessibleStatusBadge(
            label: '見積内',
            icon: Icons.check_circle_outline,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.text('見積内'), findsOneWidget);
    expect(find.bySemanticsLabel('状態: 見積内'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('comparison view switcher is operable by semantic labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = ComparisonViewMode.table;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: ComparisonViewModeSwitcher(
              value: value,
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('業者別カード形式'));
    await tester.pump();
    expect(value, ComparisonViewMode.contractorCards);
    expect(find.bySemanticsLabel('比較表示形式'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('comparison screen renders without overflow at 200 percent text', (
    tester,
  ) async {
    final project = createSampleComparisonProject();
    final repository = ProjectRepository(
      databaseService: MockDatabaseService(initialProjects: [project]),
    );
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(900, 1400),
            textScaler: TextScaler.linear(2),
          ),
          child: ComparisonScreen(
            project: project,
            repository: repository,
            adService: MockAdMobService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('業者別カード形式'), findsOneWidget);
    expect(find.textContaining('文字を大きく表示しているため'), findsOneWidget);
  });

  test('every production IconButton declares a tooltip', () {
    final missing = <String>[];
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in dartFiles) {
      final lines = file.readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (!RegExp(r'\bIconButton\s*\(').hasMatch(lines[index])) continue;
        final end = (index + 16).clamp(0, lines.length);
        final block = lines.sublist(index, end).join('\n');
        if (!block.contains('tooltip:')) {
          missing.add('${file.path}:${index + 1}');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'IconButton without tooltip: ${missing.join(', ')}',
    );
  });
}
