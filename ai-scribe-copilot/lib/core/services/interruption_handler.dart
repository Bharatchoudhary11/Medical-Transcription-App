import 'dart:async';

import 'package:flutter/services.dart';

import '../../utils/logger.dart';

enum InterruptionEventType { phoneCallStarted, phoneCallEnded, audioFocusLost, audioFocusGained }

class InterruptionEvent {
  InterruptionEvent({required this.type});

  final InterruptionEventType type;
}

class InterruptionHandler {
  InterruptionHandler({required this.logger});

  final Logger logger;
  static const _channel = MethodChannel('ai_scribe_copilot/mic');
  static const _events = EventChannel('ai_scribe_copilot/interruption');
  final _controller = StreamController<InterruptionEvent>.broadcast();

  Stream<InterruptionEvent> get events => _controller.stream;

  Future<void> initialize() async {
    _events.receiveBroadcastStream().listen((dynamic event) {
      final map = Map<String, dynamic>.from(event as Map);
      final type = InterruptionEventType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => InterruptionEventType.audioFocusLost,
      );
      logger.d('Received interruption event: $type');
      _controller.add(InterruptionEvent(type: type));
    });
  }

  Future<void> setGain(double gain) async {
    try {
      await _channel.invokeMethod('setGain', {'gain': gain});
    } on PlatformException catch (error, stackTrace) {
      logger.w('Failed to set gain', error, stackTrace);
    }
  }

  Future<void> requestAudioFocus() async {
    try {
      await _channel.invokeMethod('requestFocus');
    } on PlatformException catch (error, stackTrace) {
      logger.w('Failed to request audio focus', error, stackTrace);
    }
  }

  Future<void> abandonAudioFocus() async {
    try {
      await _channel.invokeMethod('abandonFocus');
    } on PlatformException catch (error, stackTrace) {
      logger.w('Failed to abandon audio focus', error, stackTrace);
    }
  }
}
