import 'package:flutter_test/flutter_test.dart';
import 'package:zmp3chart/config/app_config.dart';

void main() {
  group('AppConfig', () {
    test('uses localhost only for non-release builds', () {
      final config = AppConfig.fromEnvironment(
        apiBaseUrl: '',
        isRelease: false,
      );

      expect(config.isValid, isTrue);
      expect(config.apiBaseUrl, 'http://localhost:8080');
    });

    test('requires a HTTPS API URL for release builds', () {
      final missing = AppConfig.fromEnvironment(
        apiBaseUrl: '',
        isRelease: true,
      );
      final insecure = AppConfig.fromEnvironment(
        apiBaseUrl: 'http://proxy.example.com',
        isRelease: true,
      );
      final valid = AppConfig.fromEnvironment(
        apiBaseUrl: 'https://proxy.example.com/',
        isRelease: true,
      );

      expect(missing.isValid, isFalse);
      expect(insecure.isValid, isFalse);
      expect(valid.isValid, isTrue);
      expect(valid.apiBaseUrl, 'https://proxy.example.com');
    });

    test('rejects the reserved invalid release placeholder', () {
      final config = AppConfig.fromEnvironment(
        apiBaseUrl: 'https://api.example.invalid',
        isRelease: true,
      );

      expect(config.isValid, isFalse);
    });
  });
}
