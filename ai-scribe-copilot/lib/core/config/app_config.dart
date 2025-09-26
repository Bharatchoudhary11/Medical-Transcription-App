import 'package:flutter/foundation.dart';

/// Centralised runtime configuration for the app.
///
/// The backend base URL can be overridden at build time with the
/// `--dart-define=API_BASE_URL=...` flag so that developers can point the
/// mobile client at any environment (local docker, staging, production).
///
/// We also provide sensible defaults for the most common setups:
///   * Android emulator -> `10.0.2.2`
///   * iOS simulator / desktop / unit tests -> `localhost`
///   * Web builds -> `localhost`
class AppConfig {
  const AppConfig._();

  static String get apiBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3000/api';
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'http://localhost:3000/api';
      case TargetPlatform.fuchsia:
        return 'http://localhost:3000/api';
    }
  }
}
