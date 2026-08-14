import 'dart:typed_data';

import 'wrapped_export_service_stub.dart'
    if (dart.library.io) 'wrapped_export_service_io.dart'
    if (dart.library.js_interop) 'wrapped_export_service_web.dart';

enum WrappedExportResult { shared, saved, unavailable }

abstract interface class WrappedExportService {
  Future<WrappedExportResult> exportPng(
    Uint8List bytes, {
    required String fileName,
    required String title,
  });
}

WrappedExportService createWrappedExportService() =>
    createPlatformWrappedExportService();
