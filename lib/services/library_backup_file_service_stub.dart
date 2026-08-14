import 'library_backup_file_service.dart';

LibraryBackupFileService createPlatformLibraryBackupFileService() =>
    _UnsupportedLibraryBackupFileService();

class _UnsupportedLibraryBackupFileService implements LibraryBackupFileService {
  @override
  Future<bool> exportJson(String json, {required String fileName}) {
    throw UnsupportedError('Nền tảng này chưa hỗ trợ xuất file backup.');
  }

  @override
  Future<String?> importJson() {
    throw UnsupportedError('Nền tảng này chưa hỗ trợ nhập file backup.');
  }
}
