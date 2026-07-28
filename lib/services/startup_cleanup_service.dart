/// アプリ起動時に前回異常終了などで残った一時データを削除する。
library;

import '../utils/app_logger.dart';

import 'scan_storage_service.dart';

class StartupCleanupService {
  const StartupCleanupService({
    this.scanStorageService = const ScanStorageService(),
  });

  final ScanStorageService scanStorageService;

  Future<void> run() async {
    try {
      await scanStorageService.cleanupAll();
    } catch (error, stackTrace) {
      AppLogger.debug('Startup scan cleanup failed: $error\n$stackTrace');
    }
  }
}
