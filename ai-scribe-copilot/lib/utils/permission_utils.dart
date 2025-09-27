import 'package:permission_handler/permission_handler.dart';

/// Utility helpers for working with runtime permissions.
///
/// Keeping this in a shared file avoids subtle inconsistencies across
/// different screens and services when we check for microphone access.
bool hasMicrophoneAccess(PermissionStatus status) {
  return status.isGranted || status.isLimited || status.isProvisional;
}
