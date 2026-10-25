import 'file_storage_interface.dart';
import 'file_storage_stub.dart'
    if (dart.library.js_interop) 'file_storage_web.dart';

export 'file_storage_interface.dart';

FileStorageService createFileStorageService() => getFileStorageService();
