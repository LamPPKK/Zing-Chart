import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:share_plus/share_plus.dart' hide XFile;

import 'wrapped_export_service.dart';

WrappedExportService createPlatformWrappedExportService() =>
    _IoWrappedExportService();

class _IoWrappedExportService implements WrappedExportService {
  @override
  Future<WrappedExportResult> exportPng(
    Uint8List bytes, {
    required String fileName,
    required String title,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final result = await SharePlus.instance.share(
        ShareParams(
          title: title,
          subject: title,
          files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
          fileNameOverrides: [fileName],
        ),
      );
      return result.status == ShareResultStatus.unavailable
          ? WrappedExportResult.unavailable
          : WrappedExportResult.shared;
    }

    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PNG image',
          extensions: ['png'],
          mimeTypes: ['image/png'],
          uniformTypeIdentifiers: ['public.png'],
        ),
      ],
    );
    if (location == null) return WrappedExportResult.unavailable;
    await XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: fileName,
    ).saveTo(location.path);
    return WrappedExportResult.saved;
  }
}
