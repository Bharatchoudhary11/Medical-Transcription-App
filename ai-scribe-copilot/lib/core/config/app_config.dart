import 'package:flutter/foundation.dart';

/// Centralised runtime configuration for the app.
///
/// The backend base URL can be overridden at build time with the
/// `--dart-define=API_BASE_URL=...` flag so that developers can point the
/// mobile client at any environment (local docker, staging, production).
///
/// From the command line you can also specify the individual components of the
/// API URL using `API_HOST`, `API_PORT`, `API_SCHEME` and `API_PATH`. This is
/// particularly handy for IPv6 addresses where wrapping the host in square
/// brackets correctly can be error prone.
///
/// We also provide sensible defaults for the most common setups:
///   * Android emulator -> `10.0.2.2`
///   * iOS simulator / desktop / unit tests -> `localhost`
///   * Web builds -> `localhost`
class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl => _resolveBaseUrl(
        baseOverride: const String.fromEnvironment('API_BASE_URL'),
        hostOverride: const String.fromEnvironment('API_HOST'),
        schemeOverride: const String.fromEnvironment('API_SCHEME'),
        portOverride: const String.fromEnvironment('API_PORT'),
        pathOverride: const String.fromEnvironment('API_PATH'),
        platform: defaultTargetPlatform,
        isWeb: kIsWeb,
      );

  @visibleForTesting
  static String resolveBaseUrlForTest({
    String baseOverride = '',
    String hostOverride = '',
    String schemeOverride = '',
    String portOverride = '',
    String pathOverride = '',
    TargetPlatform platform = TargetPlatform.android,
    bool isWeb = false,
  }) {
    return _resolveBaseUrl(
      baseOverride: baseOverride,
      hostOverride: hostOverride,
      schemeOverride: schemeOverride,
      portOverride: portOverride,
      pathOverride: pathOverride,
      platform: platform,
      isWeb: isWeb,
    );
  }

  static String _resolveBaseUrl({
    required String baseOverride,
    required String hostOverride,
    required String schemeOverride,
    required String portOverride,
    required String pathOverride,
    required TargetPlatform platform,
    required bool isWeb,
  }) {
    final trimmedBaseOverride = baseOverride.trim();
    if (trimmedBaseOverride.isNotEmpty) {
      return _ensureTrailingSlash(trimmedBaseOverride);
    }

    final trimmedHostOverride = hostOverride.trim();
    if (trimmedHostOverride.isNotEmpty) {
      final trimmedSchemeOverride = schemeOverride.trim();
      final scheme =
          trimmedSchemeOverride.isEmpty ? 'http' : trimmedSchemeOverride;

      final trimmedPortOverride = portOverride.trim();
      final port = trimmedPortOverride.isEmpty
          ? null
          : int.tryParse(trimmedPortOverride);
      if (trimmedPortOverride.isNotEmpty && port == null) {
        throw FormatException(
          'Invalid API_PORT "$trimmedPortOverride": expected an integer.',
        );
      }

      final trimmedPathOverride = pathOverride.trim();
      final pathSegments = trimmedPathOverride.isEmpty
          ? const <String>[]
          : trimmedPathOverride
              .split('/')
              .map((segment) => segment.trim())
              .where((segment) => segment.isNotEmpty)
              .toList(growable: false);

      final uri = Uri(
        scheme: scheme,
        host: trimmedHostOverride,
        port: port,
        pathSegments: pathSegments,
      );
      return _ensureTrailingSlash(uri.toString());
    }

    if (isWeb) {
      return 'http://localhost:3000/api/';
    }

    switch (platform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api/';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://localhost:3000/api/';
      case TargetPlatform.fuchsia:
        return 'http://localhost:3000/api/';
    }
  }

  static String _ensureTrailingSlash(String baseUrl) {
    if (baseUrl.endsWith('/')) {
      return baseUrl;
    }
    return '$baseUrl/';
  }
}
