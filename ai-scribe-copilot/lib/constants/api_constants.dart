import '../core/config/app_config.dart';

class ApiConstants {
  // Base URL - resolved dynamically depending on platform and env overrides
  static String get baseUrl => AppConfig.apiBaseUrl;
  
  // Session Management Endpoints
  static const String uploadSession = '/v1/upload-session';
  static const String getPresignedUrl = '/v1/get-presigned-url';
  static const String notifyChunkUploaded = '/v1/notify-chunk-uploaded';
  
  // Patient Management Endpoints
  static const String patients = '/v1/patients';
  static const String addPatient = '/v1/add-patient-ext';
  static const String fetchSessionByPatient = '/v1/fetch-session-by-patient';
  
  // Audio Configuration
  static const int chunkSizeMs = 5000; // 5 seconds per chunk
  static const int maxRetryAttempts = 3;
  static const int retryDelayMs = 1000;
  
  // Recording Configuration
  static const String audioFormat = 'aac';
  static const int sampleRate = 44100;
  static const int bitRate = 128000;
  
  // Background Service Configuration
  static const String backgroundServiceName = 'AudioRecordingService';
  static const String notificationChannelId = 'audio_recording_channel';
  static const String notificationChannelName = 'Audio Recording';
}
