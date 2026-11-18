import 'dart:io';

import 'local_storage_driver.dart';

LocalStorageDriver createDriver({String? customDirectoryPath}) {
  return IoJsonStorageDriver(customDirectoryPath: customDirectoryPath);
}

/// Atomic file-backed [LocalStorageDriver] for Windows, macOS, Linux, Android, and iOS.
class IoJsonStorageDriver implements LocalStorageDriver {
  IoJsonStorageDriver({String? customDirectoryPath})
      : _customDirectoryPath = customDirectoryPath;

  final String? _customDirectoryPath;

  Directory _resolveBaseDir() {
    final custom = _customDirectoryPath;
    if (custom != null && custom.isNotEmpty) {
      return Directory(custom);
    }

    final env = Platform.environment;
    if (Platform.isWindows) {
      final localAppData = env['LOCALAPPDATA'] ?? env['APPDATA'];
      if (localAppData != null && localAppData.isNotEmpty) {
        return Directory('$localAppData\\AceSocietyTeenPatti');
      }
    } else if (Platform.isMacOS || Platform.isLinux) {
      final home = env['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory('$home/.ace_society_teen_patti');
      }
    }

    return Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}ace_society_teen_patti',
    );
  }

  File _fileForKey(String key) {
    final safeKey = key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final dir = _resolveBaseDir();
    return File('${dir.path}${Platform.pathSeparator}$safeKey.json');
  }

  @override
  Future<String?> readJson(String key) async {
    try {
      final file = _fileForKey(key);
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeJson(String key, String value) async {
    try {
      final file = _fileForKey(key);
      await file.parent.create(recursive: true);
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(value, flush: true);
      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (_) {
      // Fail gracefully if sandboxed filesystem denies write.
    }
  }

  @override
  Future<void> deleteJson(String key) async {
    try {
      final file = _fileForKey(key);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
