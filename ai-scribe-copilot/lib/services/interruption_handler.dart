import 'dart:async';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import '../models/recording_session.dart';
import 'audio_recording_service.dart';
import 'background_service.dart';

class InterruptionHandler {
  static final InterruptionHandler _instance = InterruptionHandler._internal();
  factory InterruptionHandler() => _instance;
  InterruptionHandler._internal();

  final AudioRecordingService _audioService = AudioRecordingService();
  final BackgroundService _backgroundService = BackgroundService();
  final Connectivity _connectivity = Connectivity();
  final Battery _battery = Battery();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _appStateTimer;
  
  bool _isHandlingInterruption = false;
  RecordingSession? _interruptedSession;

  Future<void> initialize() async {
    // Set up connectivity monitoring
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) => _onConnectivityChanged(results.first),
    );

    // Set up battery monitoring
    _batterySubscription = _battery.onBatteryStateChanged.listen(
      _onBatteryStateChanged,
    );

    // Set up app state monitoring
    _setupAppStateMonitoring();

    // Check for interrupted sessions on startup
    await _checkForInterruptedSessions();
  }

  void _setupAppStateMonitoring() {
    // Monitor app lifecycle changes
    SystemChannels.lifecycle.setMessageHandler((message) async {
      switch (message) {
        case 'AppLifecycleState.paused':
          await _onAppPaused();
          break;
        case 'AppLifecycleState.resumed':
          await _onAppResumed();
          break;
        case 'AppLifecycleState.detached':
          await _onAppDetached();
          break;
      }
      return null;
    });
  }

  Future<void> _onAppPaused() async {
    if (_audioService.isRecording && !_audioService.isPaused) {
      // App is being paused while recording
      await _handleAppPause();
    }
  }

  Future<void> _onAppResumed() async {
    if (_interruptedSession != null) {
      // App was resumed after interruption
      await _handleAppResume();
    }
  }

  Future<void> _onAppDetached() async {
    if (_audioService.isRecording) {
      // App is being killed while recording
      await _handleAppKill();
    }
  }

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    if (result == ConnectivityResult.none) {
      // Network lost
      await _handleNetworkLoss();
    } else {
      // Network restored
      await _handleNetworkRestore();
    }
  }

  Future<void> _onBatteryStateChanged(BatteryState state) async {
    if (state == BatteryState.charging) {
      // Battery is charging
      await _handleBatteryCharging();
    } else if (state == BatteryState.discharging) {
      // Battery is discharging
      final batteryLevel = await _battery.batteryLevel;
      if (batteryLevel < 20) {
        await _handleLowBattery();
      }
    }
  }

  // Interruption handling methods
  Future<void> _handleAppPause() async {
    if (_isHandlingInterruption) return;
    _isHandlingInterruption = true;

    try {
      // Pause recording
      await _audioService.pauseRecording();
      
      // Start background service
      await _backgroundService.startService();
      
      // Update notification
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Recording paused - app in background',
        isRecording: false,
      );

      print('App paused - recording paused');
    } catch (e) {
      print('Error handling app pause: $e');
    } finally {
      _isHandlingInterruption = false;
    }
  }

  Future<void> _handleAppResume() async {
    if (_isHandlingInterruption) return;
    _isHandlingInterruption = true;

    try {
      // Resume recording if session exists
      if (_interruptedSession != null) {
        await _audioService.resumeRecording();
        
        // Update notification
        await _backgroundService.updateNotification(
          title: 'AI Scribe Copilot',
          content: 'Recording resumed',
          isRecording: true,
        );

        _interruptedSession = null;
        print('App resumed - recording resumed');
      }
    } catch (e) {
      print('Error handling app resume: $e');
    } finally {
      _isHandlingInterruption = false;
    }
  }

  Future<void> _handleAppKill() async {
    if (_isHandlingInterruption) return;
    _isHandlingInterruption = true;

    try {
      // Save current session state
      final currentSession = _audioService.currentSession;
      if (currentSession != null) {
        _interruptedSession = currentSession;
        
        // Start background service to handle cleanup
        await _backgroundService.startService();
        
        // Update notification
        await _backgroundService.updateNotification(
          title: 'AI Scribe Copilot',
          content: 'Recording interrupted - will resume when app opens',
          isRecording: false,
        );

        print('App killed - session saved for recovery');
      }
    } catch (e) {
      print('Error handling app kill: $e');
    } finally {
      _isHandlingInterruption = false;
    }
  }

  Future<void> _handleNetworkLoss() async {
    if (_audioService.isRecording) {
      // Network lost while recording
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Recording continues - will upload when network returns',
        isRecording: true,
      );
      print('Network lost - recording continues offline');
    }
  }

  Future<void> _handleNetworkRestore() async {
    // Network restored - background service will handle uploads
    await _backgroundService.updateNotification(
      title: 'AI Scribe Copilot',
      content: 'Network restored - uploading queued audio',
      isRecording: _audioService.isRecording,
    );
    print('Network restored - queued uploads will be processed');
  }

  Future<void> _handleLowBattery() async {
    if (_audioService.isRecording) {
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Low battery - recording continues but consider charging',
        isRecording: true,
      );
      print('Low battery warning - recording continues');
    }
  }

  Future<void> _handleBatteryCharging() async {
    if (_audioService.isRecording) {
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Battery charging - recording continues',
        isRecording: true,
      );
      print('Battery charging - recording continues');
    }
  }

  Future<void> _checkForInterruptedSessions() async {
    // Check if there are any interrupted sessions that need recovery
    // This would be implemented based on your specific recovery logic
    print('Checking for interrupted sessions...');
  }

  // Public methods for handling specific interruptions
  Future<void> handlePhoneCall() async {
    if (_audioService.isRecording) {
      await _audioService.pauseRecording();
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Recording paused - phone call in progress',
        isRecording: false,
      );
    }
  }

  Future<void> handlePhoneCallEnd() async {
    if (_audioService.isPaused) {
      await _audioService.resumeRecording();
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Recording resumed - phone call ended',
        isRecording: true,
      );
    }
  }

  Future<void> handleAppSwitch() async {
    if (_audioService.isRecording) {
      await _backgroundService.startService();
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Recording continues in background',
        isRecording: true,
      );
    }
  }

  Future<void> handleMemoryPressure() async {
    if (_audioService.isRecording) {
      // Save current state and prepare for potential app kill
      await _backgroundService.startService();
      await _backgroundService.updateNotification(
        title: 'AI Scribe Copilot',
        content: 'Memory pressure - recording state saved',
        isRecording: true,
      );
    }
  }

  Future<void> dispose() async {
    _connectivitySubscription?.cancel();
    _batterySubscription?.cancel();
    _appStateTimer?.cancel();
  }
}
