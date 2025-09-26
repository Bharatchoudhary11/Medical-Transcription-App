import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../core/services/audio_recorder_service.dart';
import '../core/services/background_task_manager.dart';
import '../core/services/chunk_persistence_service.dart';
import '../core/services/chunk_uploader.dart';
import '../core/services/connectivity_monitor.dart';
import '../core/services/interruption_handler.dart';
import '../core/services/patient_service.dart';
import '../core/services/upload_session_service.dart';
import '../utils/logger.dart';
import '../utils/theme.dart';

final themeProvider = Provider<AppTheme>((ref) => createTheme());

Future<List<Override>> buildOverrides() async {
  final logger = Logger();
  final apiClient = ApiClient(logger: logger);
  final chunkStore = ChunkPersistenceService(logger: logger);
  await chunkStore.ensureInitialized();
  final backgroundTaskManager = BackgroundTaskManager(logger: logger);
  await backgroundTaskManager.initialize();
  final connectivityMonitor = ConnectivityMonitor(logger: logger);
  await connectivityMonitor.initialize();
  final interruptionHandler = InterruptionHandler(logger: logger);
  await interruptionHandler.initialize();
  final audioRecorderService = AudioRecorderService(
    logger: logger,
    chunkPersistenceService: chunkStore,
    interruptionHandler: interruptionHandler,
  );
  await audioRecorderService.initialize();
  final uploadSessionService = UploadSessionService(
    apiClient: apiClient,
    logger: logger,
  );
  final chunkUploader = ChunkUploader(
    logger: logger,
    chunkStore: chunkStore,
    uploadSessionService: uploadSessionService,
    connectivityMonitor: connectivityMonitor,
    backgroundTaskManager: backgroundTaskManager,
  );
  await chunkUploader.resumePendingBacklog();
  final patientService = PatientService(
    apiClient: apiClient,
    logger: logger,
  );
  return [
    apiClientProvider.overrideWithValue(apiClient),
    loggerProvider.overrideWithValue(logger),
    chunkStoreProvider.overrideWithValue(chunkStore),
    backgroundTaskManagerProvider.overrideWithValue(backgroundTaskManager),
    connectivityMonitorProvider.overrideWithValue(connectivityMonitor),
    interruptionHandlerProvider.overrideWithValue(interruptionHandler),
    audioRecorderServiceProvider.overrideWithValue(audioRecorderService),
    uploadSessionServiceProvider.overrideWithValue(uploadSessionService),
    chunkUploaderProvider.overrideWithValue(chunkUploader),
    patientServiceProvider.overrideWithValue(patientService),
  ];
}

final loggerProvider = Provider<Logger>((ref) => throw UnimplementedError());
final apiClientProvider = Provider<ApiClient>((ref) => throw UnimplementedError());
final chunkStoreProvider = Provider<ChunkPersistenceService>((ref) => throw UnimplementedError());
final backgroundTaskManagerProvider = Provider<BackgroundTaskManager>((ref) => throw UnimplementedError());
final connectivityMonitorProvider = Provider<ConnectivityMonitor>((ref) => throw UnimplementedError());
final interruptionHandlerProvider = Provider<InterruptionHandler>((ref) => throw UnimplementedError());
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) => throw UnimplementedError());
final uploadSessionServiceProvider = Provider<UploadSessionService>((ref) => throw UnimplementedError());
final chunkUploaderProvider = Provider<ChunkUploader>((ref) => throw UnimplementedError());
final patientServiceProvider = Provider<PatientService>((ref) => throw UnimplementedError());
