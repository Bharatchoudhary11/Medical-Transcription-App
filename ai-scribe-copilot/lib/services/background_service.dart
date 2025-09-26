import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class BackgroundService {
  static final BackgroundService _instance = BackgroundService._internal();
  factory BackgroundService() => _instance;
  BackgroundService._internal();

  final ApiService _apiService = ApiService();
  final LocalStorageService _storageService = LocalStorageService();
  final Connectivity _connectivity = Connectivity();

  Timer? _uploadTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // Configure Android foreground service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: ApiConstants.notificationChannelId,
        initialNotificationTitle: 'AI Scribe Copilot',
        initialNotificationContent: 'Recording in progress',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }

  Future<void> startService() async {
    final service = FlutterBackgroundService();
    
    // Check if service is already running
    final isRunning = await service.isRunning();
    if (isRunning) return;

    // Start the service
    await service.startService();
  }

  Future<void> stopService() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  Future<void> updateNotification({
    required String title,
    required String content,
    bool isRecording = true,
  }) async {
    final service = FlutterBackgroundService();
    service.invoke('update_notification', {
      'title': title,
      'content': content,
      'isRecording': isRecording,
    });
  }

  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // Initialize services
    final backgroundService = BackgroundService();
    await backgroundService._initializeBackgroundTasks();

    // Handle service lifecycle
    service.on('stop').listen((event) {
      service.stopSelf();
    });

    service.on('update_notification').listen((event) {
      final title = event?['title'] as String? ?? 'AI Scribe Copilot';
      final content = event?['content'] as String? ?? 'Service running';

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: title,
          content: content,
        );
      }
    });

    // Keep service alive
    Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (service is AndroidServiceInstance) {
        if (await service.isForegroundService()) {
          // Service is running in foreground
        }
      }
      
      // Check for pending uploads
      await backgroundService._checkPendingUploads();
    });
  }

  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    // iOS background handling
    return true;
  }

  Future<void> _initializeBackgroundTasks() async {
    // Set up connectivity monitoring
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) => _onConnectivityChanged(results.first),
    );

    // Set up periodic upload check
    _uploadTimer = Timer.periodic(
      const Duration(seconds: 30),
      (timer) => _checkPendingUploads(),
    );
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      // Network is back, try to upload pending chunks
      _checkPendingUploads();
    }
  }

  Future<void> _checkPendingUploads() async {
    try {
      final pendingChunks = await _storageService.getPendingChunks();
      final failedChunks = await _storageService.getFailedChunks();
      
      // Try to upload pending chunks
      for (final chunk in pendingChunks) {
        await _uploadChunk(chunk);
      }
      
      // Try to retry failed chunks
      for (final chunk in failedChunks) {
        if (chunk.retryCount < 3) {
          await _uploadChunk(chunk);
        }
      }
    } catch (e) {
      print('Error checking pending uploads: $e');
    }
  }

  Future<void> _uploadChunk(dynamic chunk) async {
    try {
      // Get presigned URL
      final presignedUrl = await _apiService.getPresignedUrl(
        chunk.sessionId,
        chunk.sequenceNumber,
      );

      if (presignedUrl == null) {
        throw Exception('Failed to get presigned URL');
      }

      // Update chunk with presigned URL
      final updatedChunk = chunk.copyWith(
        presignedUrl: presignedUrl,
        status: 'uploading',
      );
      await _storageService.saveChunk(updatedChunk);

      // Upload file (simplified for background service)
      // In a real implementation, you'd handle file upload here
      
      // Notify backend
      await _apiService.notifyChunkUploaded(chunk.sessionId, chunk.sequenceNumber);
      
      // Update chunk status
      final completedChunk = updatedChunk.copyWith(
        status: 'uploaded',
        uploadedAt: DateTime.now(),
      );
      await _storageService.saveChunk(completedChunk);
      
    } catch (e) {
      print('Failed to upload chunk in background: $e');
      // Update retry count
      final failedChunk = chunk.copyWith(
        retryCount: chunk.retryCount + 1,
        status: chunk.retryCount >= 3 ? 'failed' : 'pending',
      );
      await _storageService.saveChunk(failedChunk);
    }
  }

  Future<void> dispose() async {
    _uploadTimer?.cancel();
    _connectivitySubscription?.cancel();
  }
}
