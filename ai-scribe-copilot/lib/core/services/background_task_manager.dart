import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import '../../utils/logger.dart';

class BackgroundTaskManager {
  BackgroundTaskManager({required this.logger});

  final Logger logger;
  final FlutterBackgroundService _service = FlutterBackgroundService();

  Future<void> initialize() async {
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  Future<void> ensureServiceRunning() async {
    final isRunning = await _service.isRunning();
    if (!isRunning) {
      logger.d('Starting background service');
      await _service.startService();
    }
  }

  Future<void> stopService() async {
    if (await _service.isRunning()) {
      await _service.stopService();
    }
  }

  static Future<void> _onStart(ServiceInstance service) async {
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'AI Scribe Copilot',
        content: 'Capturing clinical audio securely',
      );
    }
  }

  static Future<bool> _onIosBackground(ServiceInstance service) async {
    return true;
  }
}
