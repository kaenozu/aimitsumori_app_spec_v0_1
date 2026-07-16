/// ファイルパス: lib/services/haptic_service.dart
/// 主要操作の触覚フィードバックを統一するサービス
library;

import 'package:flutter/services.dart';

class HapticService {
  const HapticService._();

  static Future<void> lightImpact() => HapticFeedback.lightImpact();

  static Future<void> mediumImpact() => HapticFeedback.mediumImpact();
}
