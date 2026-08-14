import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart' hide XFile;

import 'library_backup_file_service.dart';

const _maxBackupBytes = 5 * 1024 * 1024;

LibraryBackupFileService createPlatformLibraryBackupFileService() =>
    _WebLibraryBackupFileService();

class _WebLibraryBackupFileService implements LibraryBackupFileService {
  static const _jsonTypes = XTypeGroup(
    label: '#zingChart JSON',
    extensions: ['json'],
    mimeTypes: ['application/json'],
    webWildCards: ['application/json'],
  );

  @override
  Future<bool> exportJson(String json, {required String fileName}) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: 'Backup thư viện #zingChart',
        files: [
          XFile.fromData(
            Uint8List.fromList(utf8.encode(json)),
            mimeType: 'application/json',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
        downloadFallbackEnabled: true,
      ),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  @override
  Future<String?> importJson() async {
    final file = await openFile(acceptedTypeGroups: const [_jsonTypes]);
    if (file == null) return null;
    if (await file.length() > _maxBackupBytes) {
      throw const FormatException('File backup lớn hơn giới hạn 5 MB.');
    }
    return file.readAsString();
  }
}
