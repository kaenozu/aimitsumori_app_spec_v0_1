/// ファイルパス: lib/services/haptic_service.dart
/// 主要操作の触覚フィードバックを統一するサービス
library;

import 'package:flutter/services.dart';

class HapticService {
  const HapticService._();

  static Future<void> lightImpact() => _perform(HapticFeedback.lightImpact);

  static Future<void> mediumImpact() => _perform(HapticFeedback.mediumImpact);

  static Future<void> _perform(Future<void> Function() feedback) async {
    try {
      await feedback();
    } on MissingPluginException {
      // Widget tests and unsupported platforms may not provide haptics.
    } on PlatformException {
      // Haptic feedback must never block the primary user action.
    }
  }
}
