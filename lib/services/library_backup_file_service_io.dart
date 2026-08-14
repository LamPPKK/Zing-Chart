import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart' hide XFile;

import 'library_backup_file_service.dart';

const _maxBackupBytes = 5 * 1024 * 1024;

LibraryBackupFileService createPlatformLibraryBackupFileService() =>
    _IoLibraryBackupFileService();

class _IoLibraryBackupFileService implements LibraryBackupFileService {
  @override
  Future<bool> exportJson(String json, {required String fileName}) async {
    final bytes = Uint8List.fromList(utf8.encode(json));
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: 'Backup thư viện #zingChart',
          subject: 'Backup thư viện #zingChart',
          files: [
            XFile.fromData(bytes, mimeType: 'application/json', name: fileName),
          ],
          fileNameOverrides: [fileName],
        ),
      );
      return result.status != ShareResultStatus.unavailable;
    }

    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [_jsonTypeGroup()],
    );
    if (location == null) return false;
    await XFile.fromData(
      bytes,
      mimeType: 'application/json',
      name: fileName,
    ).saveTo(location.path);
    return true;
  }

  @override
  Future<String?> importJson() async {
    final file = await openFile(acceptedTypeGroups: [_jsonTypeGroup()]);
    if (file == null) return null;
    if (await file.length() > _maxBackupBytes) {
      throw const FormatException('File backup lớn hơn giới hạn 5 MB.');
    }
    return file.readAsString();
  }

  XTypeGroup _jsonTypeGroup() {
    if (Platform.isIOS) {
      return const XTypeGroup(
        label: '#zingChart JSON',
        uniformTypeIdentifiers: ['public.json'],
      );
    }
    if (Platform.isAndroid) {
      return const XTypeGroup(
        label: '#zingChart JSON',
        extensions: ['json'],
        mimeTypes: ['application/json'],
      );
    }
    return const XTypeGroup(label: '#zingChart JSON', extensions: ['json']);
  }
}
