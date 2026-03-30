import 'package:ebs_lite/core/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.resolveApiBaseUrl', () {
    test('uses the localhost fallback outside release mode', () {
      final value = AppConfig.resolveApiBaseUrl(
        configuredValue: '',
        isReleaseMode: false,
      );

      expect(value, 'http://127.0.0.1:8080/api/v1');
    });

    test('accepts an explicit non-local release URL', () {
      final value = AppConfig.resolveApiBaseUrl(
        configuredValue: 'https://api.example.com/api/v1',
        isReleaseMode: true,
      );

      expect(value, 'https://api.example.com/api/v1');
    });

    test('rejects localhost release URLs', () {
      expect(
        () => AppConfig.resolveApiBaseUrl(
          configuredValue: 'http://127.0.0.1:8080/api/v1',
          isReleaseMode: true,
        ),
        throwsStateError,
      );
    });
  });
}
