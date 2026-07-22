library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ScanStorageService {
  const ScanStorageService();

  Future<String> persistCapture({
    required String sourcePath,
    required String projectId,
    required String sessionId,
    required String pageId,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      p.join(
        root.path,
        'scans',
        _safeSegment(projectId),
        _safeSegment(sessionId),
      ),
    );
    await directory.create(recursive: true);
    final extension = p.extension(sourcePath).toLowerCase();
    final target = File(
      p.join(
        directory.path,
        '${_safeSegment(pageId)}${extension.isEmpty ? '.jpg' : extension}',
      ),
    );
    await File(sourcePath).copy(target.path);
    return target.path;
  }

  Future<void> deletePath(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 個別ページ削除失敗はOSのストレージ管理へ委ねる。
    }
  }

  Future<void> cleanupSession({
    required String projectId,
    required String sessionId,
  }) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory(
        p.join(
          root.path,
          'scans',
          _safeSegment(projectId),
          _safeSegment(sessionId),
        ),
      );
      if (await directory.exists()) await directory.delete(recursive: true);
    } catch (_) {
      // キャンセル時の削除失敗は次回OSクリーンアップへ委ねる。
    }
  }

  String _safeSegment(String value) => value.replaceAll(
        RegExp(r'[^a-zA-Z0-9._-]'),
        '_',
      );
}
