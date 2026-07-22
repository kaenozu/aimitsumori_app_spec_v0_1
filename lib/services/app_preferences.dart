/// ファイルパス: lib/services/app_preferences.dart
/// アプリ設定をSharedPreferencesへ保存するサービス
library;

import 'package:shared_preferences/shared_preferences.dart';

class AppPreferences {
  AppPreferences({Future<SharedPreferences> Function()? preferencesLoader})
    : _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  static final AppPreferences instance = AppPreferences();

  static const _darkModeKey = 'dark_mode_enabled';

  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<bool> isDarkModeEnabled() async {
    final preferences = await _preferencesLoader();
    return preferences.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkModeEnabled(bool enabled) async {
    final preferences = await _preferencesLoader();
    final saved = await preferences.setBool(_darkModeKey, enabled);
    if (!saved) {
      throw StateError('ダークモード設定を保存できませんでした。');
    }
  }
}
