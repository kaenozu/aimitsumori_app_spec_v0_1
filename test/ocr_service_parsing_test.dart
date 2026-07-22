import 'package:aimitsumori_app/services/ocr_service.dart';
import 'package:aimitsumori_app/services/ocr_review_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses a Japanese estimate contractor and total amount', () {
    final quote = OcrService.parseTextForTesting('''
御見積書
株式会社青空外構
工事名：新築外構工事
御見積金額 2,530,000円
''');

    expect(quote.contractorName, '株式会社青空外構');
    expect(quote.totalAmountYen, 2530000);
  });

  test('parses total amount when OCR separates the keyword and currency', () {
    final quote = OcrService.parseTextForTesting('''
有限会社みどり建設
税込合計：￥1 248 000
''');

    expect(quote.contractorName, '有限会社みどり建設');
    expect(quote.totalAmountYen, 1248000);
  });

  test('does not persist the source file path in the quote note', () {
    final raw = OcrService.parseTextForTesting('株式会社テスト\n合計 123,000円');
    final quote = raw.toContractorQuote();

    expect(quote.note, 'OCR取込');
    expect(quote.note, isNot(contains('test://')));
  });

  test('generates different IDs for consecutive quote saves', () async {
    final raw = OcrService.parseTextForTesting('株式会社テスト\n合計 123,000円');
    final first = raw.toContractorQuote();
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final second = raw.toContractorQuote();

    expect(second.id, isNot(first.id));
  });

  test('clears only OCR review state keys', () async {
    SharedPreferences.setMockInitialValues({
      'ocr_review_states_v1_1234': '{"line":"confirmed"}',
      'dark_mode_enabled': true,
      'unrelated': 'keep',
    });
    final preferences = await SharedPreferences.getInstance();
    await OcrReviewStore(preferences: preferences).clearAll();

    expect(preferences.getString('ocr_review_states_v1_1234'), isNull);
    expect(preferences.getBool('dark_mode_enabled'), isTrue);
    expect(preferences.getString('unrelated'), 'keep');
  });
}
