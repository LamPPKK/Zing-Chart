import 'package:flutter/foundation.dart';

class AppConfig {
  const AppConfig._({required this.apiBaseUrl, this.errorMessage});

  factory AppConfig.fromEnvironment({
    String? apiBaseUrl,
    bool isRelease = kReleaseMode,
  }) {
    final rawValue =
        apiBaseUrl ??
        const String.fromEnvironment('API_BASE_URL', defaultValue: '');
    final normalized = rawValue.trim().replaceFirst(RegExp(r'/$'), '');

    if (normalized.isEmpty && !isRelease) {
      return const AppConfig._(apiBaseUrl: 'http://localhost:8080');
    }

    final uri = Uri.tryParse(normalized);
    final validScheme =
        uri?.scheme == 'https' || (!isRelease && uri?.scheme == 'http');
    if (uri == null ||
        !uri.hasAuthority ||
        !validScheme ||
        uri.host.endsWith('.invalid') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return const AppConfig._(
        apiBaseUrl: '',
        errorMessage:
            'API_BASE_URL chưa được cấu hình bằng một HTTPS URL hợp lệ.',
      );
    }

    return AppConfig._(apiBaseUrl: normalized);
  }

  final String apiBaseUrl;
  final String? errorMessage;

  bool get isValid => errorMessage == null;
}
