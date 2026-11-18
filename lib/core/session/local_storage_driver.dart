import 'local_storage_stub.dart'
    if (dart.library.io) 'local_storage_io.dart' as platform_driver;

/// Key-value JSON string persistence driver used by [AppSessionStore].
abstract interface class LocalStorageDriver {
  Future<String?> readJson(String key);
  Future<void> writeJson(String key, String value);
  Future<void> deleteJson(String key);
}

/// Fast, deterministic in-memory storage driver used by unit/widget tests
/// and fallback environments.
class InMemoryStorageDriver implements LocalStorageDriver {
  final Map<String, String> _store = <String, String>{};

  @override
  Future<String?> readJson(String key) async => _store[key];

  @override
  Future<void> writeJson(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> deleteJson(String key) async {
    _store.remove(key);
  }
}

/// Creates a persistent platform storage driver (atomic JSON file on IO,
/// in-memory fallback on web).
LocalStorageDriver createPlatformStorageDriver({String? customDirectoryPath}) {
  return platform_driver.createDriver(customDirectoryPath: customDirectoryPath);
}
