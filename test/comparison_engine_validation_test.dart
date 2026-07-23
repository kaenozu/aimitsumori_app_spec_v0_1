import 'package:aimitsumori_app/comparison_engine.dart';
import 'package:aimitsumori_app/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duplicate quote IDs are rejected outside assert mode', () {
    const project = Project(
      id: 'project-1',
      name: '外構工事',
      status: ProjectStatus.comparing,
      createdAtEpochMillis: 1,
      updatedAtEpochMillis: 1,
    );
    const quote = NormalizedQuote(
      quoteId: 'quote-1',
      contractorName: 'A社',
    );

    expect(
      () => ComparisonEngine().compare(
        project: project,
        normalizedQuotes: const [quote, quote],
        questions: const [],
      ),
      throwsArgumentError,
    );
  });
}
