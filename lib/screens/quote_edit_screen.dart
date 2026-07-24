/// ファイルパス: lib/screens/quote_edit_screen.dart
/// QuoteInputScreenを「編集」画面名で利用するための互換エントリ。
library;

import 'quote_input_screen.dart';

class QuoteEditScreen extends QuoteInputScreen {
  const QuoteEditScreen({
    super.key,
    required super.project,
    super.repository,
    super.ocrService,
    super.reviewStore,
    super.initialQuote,
    super.revisionIntent,
  });
}
