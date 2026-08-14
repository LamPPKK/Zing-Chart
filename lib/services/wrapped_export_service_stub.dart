import 'dart:typed_data';

import 'wrapped_export_service.dart';

WrappedExportService createPlatformWrappedExportService() =>
    _UnsupportedWrappedExportService();

class _UnsupportedWrappedExportService implements WrappedExportService {
  @override
  Future<WrappedExportResult> exportPng(
    Uint8List bytes, {
    required String fileName,
    required String title,
  }) async => WrappedExportResult.unavailable;
}
