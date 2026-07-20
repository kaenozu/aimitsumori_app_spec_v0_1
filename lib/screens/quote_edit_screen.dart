/// ファイルパス: lib/screens/quote_edit_screen.dart
/// 目的: QuoteInputScreen を「編集」画面名で利用するための互換エントリを提供する。
/// 存在理由: 既存の QuoteInputScreen 参照を壊さず、画面の役割とファイル名を一致させるため。
library;

import '../models.dart';
import '../repositories/project_repository.dart';
import '../services/ocr_service.dart';
import '../services/ocr_review_store.dart';
import 'quote_input_screen.dart';

class QuoteEditScreen extends QuoteInputScreen {
  const QuoteEditScreen({
    super.key,
    required Project project,
    ProjectRepository? repository,
    OcrService? ocrService,
    OcrReviewStore? reviewStore,
  }) : super(
         project: project,
         repository: repository,
         ocrService: ocrService,
         reviewStore: reviewStore,
       );
}
