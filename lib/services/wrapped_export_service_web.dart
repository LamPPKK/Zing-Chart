import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import 'wrapped_export_service.dart';

WrappedExportService createPlatformWrappedExportService() =>
    _WebWrappedExportService();

class _WebWrappedExportService implements WrappedExportService {
  @override
  Future<WrappedExportResult> exportPng(
    Uint8List bytes, {
    required String fileName,
    required String title,
  }) async {
    final result = await SharePlus.instance.share(
      ShareParams(
        title: title,
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        downloadFallbackEnabled: true,
      ),
    );
    return result.status == ShareResultStatus.unavailable
        ? WrappedExportResult.unavailable
        : WrappedExportResult.shared;
  }
}
