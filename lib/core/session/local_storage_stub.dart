import 'local_storage_driver.dart';

LocalStorageDriver createDriver({String? customDirectoryPath}) {
  return InMemoryStorageDriver();
}
