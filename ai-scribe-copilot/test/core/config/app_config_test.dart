import 'package:ai_scribe_copilot/core/config/app_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig.resolveBaseUrlForTest', () {
    test('returns trimmed API_BASE_URL override when provided', () {
      expect(
        AppConfig.resolveBaseUrlForTest(
          baseOverride: '  https://example.com/api  ',
          platform: TargetPlatform.android,
        ),
        'https://example.com/api/',
      );
    });

    test('builds URI from IPv6 host components', () {
      expect(
        AppConfig.resolveBaseUrlForTest(
          hostOverride: '2409:40d4:2405:9e6b:8000::',
          portOverride: '3000',
          pathOverride: 'api',
          schemeOverride: 'http',
        ),
        'http://[2409:40d4:2405:9e6b:8000::]:3000/api/',
      );
    });

    test('normalises custom path segments', () {
      expect(
        AppConfig.resolveBaseUrlForTest(
          hostOverride: 'api.example.com',
          portOverride: '8080',
          pathOverride: '/v1//patients/',
          schemeOverride: 'https',
        ),
        'https://api.example.com:8080/v1/patients/',
      );
    });

    test('throws when API_PORT is not numeric', () {
      expect(
        () => AppConfig.resolveBaseUrlForTest(
          hostOverride: 'api.example.com',
          portOverride: 'abc',
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('falls back to localhost for web builds', () {
      expect(
        AppConfig.resolveBaseUrlForTest(
          isWeb: true,
          platform: TargetPlatform.android,
        ),
        'http://localhost:3000/api/',
      );
    });

    test('falls back to Android emulator defaults', () {
      expect(
        AppConfig.resolveBaseUrlForTest(
          platform: TargetPlatform.android,
        ),
        'http://10.0.2.2:3000/api/',
      );
    });

    test('falls back to localhost for desktop platforms', () {
      expect(
        AppConfig.resolveBaseUrlForTest(
          platform: TargetPlatform.windows,
        ),
        'http://localhost:3000/api/',
      );
    });
  });
}
