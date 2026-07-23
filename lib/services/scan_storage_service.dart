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
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw StateError('撮影元ファイルが見つかりません。');
    }
    final root = await _scanRoot();
    final directory = Directory(
      p.join(
        root.path,
        _safeSegment(projectId),
        _safeSegment(sessionId),
      ),
    );
    await directory.create(recursive: true);

    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = RegExp(r'^\.[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : '.jpg';
    final target = File(
      p.join(directory.path, '${_safeSegment(pageId)}$safeExtension'),
    );
    _assertInsideRoot(root, target.path);
    await source.copy(target.path);
    return target.path;
  }

  Future<void> deletePath(String path) async {
    final root = await _scanRoot();
    _assertInsideRoot(root, path);
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<void> cleanupSession({
    required String projectId,
    required String sessionId,
  }) async {
    final root = await _scanRoot();
    final directory = Directory(
      p.join(
        root.path,
        _safeSegment(projectId),
        _safeSegment(sessionId),
      ),
    );
    _assertInsideRoot(root, directory.path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> cleanupProject(String projectId) async {
    final root = await _scanRoot();
    final directory = Directory(p.join(root.path, _safeSegment(projectId)));
    _assertInsideRoot(root, directory.path);
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<void> cleanupAll() async {
    final root = await _scanRoot();
    if (await root.exists()) await root.delete(recursive: true);
  }

  Future<Directory> _scanRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory(p.join(documents.path, 'scans'));
  }

  String _safeSegment(String value) {
    final trimmed = value.trim();
    final sanitized = trimmed.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      throw ArgumentError.value(value, 'path segment', '安全なIDではありません。');
    }
    return sanitized;
  }

  void _assertInsideRoot(Directory root, String candidatePath) {
    final normalizedRoot = p.normalize(p.absolute(root.path));
    final normalizedCandidate = p.normalize(p.absolute(candidatePath));
    if (!p.isWithin(normalizedRoot, normalizedCandidate)) {
      throw StateError('スキャン保存領域外のパスは操作できません。');
    }
  }
}
