import 'package:aimitsumori_app/services/scan_storage_service.dart';
import 'package:aimitsumori_app/services/startup_cleanup_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeScanStorageService extends ScanStorageService {
  _FakeScanStorageService({this.error});

  final Object? error;
  int cleanupCalls = 0;

  @override
  Future<void> cleanupAll() async {
    cleanupCalls++;
    final failure = error;
    if (failure != null) throw failure;
  }
}

void main() {
  test('removes transient scan storage during startup', () async {
    final storage = _FakeScanStorageService();
    final service = StartupCleanupService(scanStorageService: storage);

    await service.run();

    expect(storage.cleanupCalls, 1);
  });

  test('cleanup failure does not block app startup', () async {
    final storage = _FakeScanStorageService(error: StateError('disk error'));
    final service = StartupCleanupService(scanStorageService: storage);

    await expectLater(service.run(), completes);

    expect(storage.cleanupCalls, 1);
  });
}
