/// ファイルパス: lib/utils/app_logger.dart
/// アプリ全体で使用するロガー。debugPrint の代わりに使用し、本番環境でもログが残るようにする。
library;

import 'dart:developer';

class AppLogger {
  AppLogger._();

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, name: 'app_debug', error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, name: 'app_warning', error: error, stackTrace: stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    log(message, name: 'app_error', error: error, stackTrace: stackTrace);
  }
}