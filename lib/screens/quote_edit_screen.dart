/// ファイルパス: lib/screens/quote_edit_screen.dart
/// 目的: QuoteInputScreen を「編集」画面名で利用するための互換エントリを提供する。
/// 存在理由: 既存の QuoteInputScreen 参照を壊さず、画面の役割とファイル名を一致させるため。
library;

import 'quote_input_screen.dart';

class QuoteEditScreen extends QuoteInputScreen {
  const QuoteEditScreen({
    super.key,
    required super.project,
    super.repository,
    super.ocrService,
    super.reviewStore,
  });
}
