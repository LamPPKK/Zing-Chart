import 'library_backup_file_service_stub.dart'
    if (dart.library.io) 'library_backup_file_service_io.dart'
    if (dart.library.js_interop) 'library_backup_file_service_web.dart';

abstract interface class LibraryBackupFileService {
  Future<bool> exportJson(String json, {required String fileName});

  Future<String?> importJson();
}

LibraryBackupFileService createLibraryBackupFileService() =>
    createPlatformLibraryBackupFileService();
