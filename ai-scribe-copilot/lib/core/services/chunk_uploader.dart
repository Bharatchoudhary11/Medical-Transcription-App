import 'dart:async';
import 'dart:io';

import '../../utils/logger.dart';
import '../models/recording_chunk.dart';
import '../models/upload_session.dart';
import 'background_task_manager.dart';
import 'chunk_persistence_service.dart';
import 'connectivity_monitor.dart';
import 'upload_session_service.dart';

class ChunkUploader {
  ChunkUploader({
    required this.logger,
    required this.chunkStore,
    required this.uploadSessionService,
    required this.connectivityMonitor,
    required this.backgroundTaskManager,
  });

  final Logger logger;
  final ChunkPersistenceService chunkStore;
  final UploadSessionService uploadSessionService;
  final ConnectivityMonitor connectivityMonitor;
  final BackgroundTaskManager backgroundTaskManager;

  UploadSession? _activeSession;
  bool _isUploading = false;
  StreamSubscription<RecordingChunk>? _chunkSubscription;
  StreamSubscription<bool>? _onlineSubscription;
  bool _hasResumedBacklog = false;

  void bindToRecorder(Stream<RecordingChunk> chunkStream) {
    _chunkSubscription?.cancel();
    _chunkSubscription = chunkStream.listen((chunk) {
      logger.d('Chunk received from recorder: ${chunk.id}');
      _uploadPendingChunks();
    });
    _onlineSubscription ??= connectivityMonitor.onlineStream.listen((online) {
      if (online) {
        _uploadPendingChunks();
      }
    });
  }

  Future<void> startSession(UploadSession session) async {
    _activeSession = session;
    await backgroundTaskManager.ensureServiceRunning();
    await _uploadPendingChunks();
  }

  Future<void> stopSession() async {
    _activeSession = null;
    final remaining = await chunkStore.pendingChunks();
    if (remaining.isEmpty) {
      await backgroundTaskManager.stopService();
    }
  }

  Future<void> resumePendingBacklog() async {
    if (_hasResumedBacklog) {
      return;
    }
    _hasResumedBacklog = true;
    final pending = await chunkStore.pendingChunks();
    if (pending.isEmpty) {
      return;
    }
    await backgroundTaskManager.ensureServiceRunning();
    await _uploadPendingChunks();
  }

  Future<void> _uploadPendingChunks() async {
    if (_isUploading) return;
    _isUploading = true;
    try {
      final chunks = await chunkStore.pendingChunks();
      if (chunks.isEmpty) {
        return;
      }
      if (_activeSession != null) {
        chunks.sort((a, b) {
          final aActive = a.sessionId == _activeSession!.sessionId;
          final bActive = b.sessionId == _activeSession!.sessionId;
          if (aActive != bActive) {
            return aActive ? -1 : 1;
          }
          return a.createdAt.compareTo(b.createdAt);
        });
      }
      for (final chunk in chunks) {
        await _uploadChunk(chunk);
      }
      final remaining = await chunkStore.pendingChunks();
      if (remaining.isEmpty && _activeSession == null) {
        await backgroundTaskManager.stopService();
      }
    } finally {
      _isUploading = false;
    }
  }

  Future<void> _uploadChunk(RecordingChunk chunk) async {
    try {
      final presigned = await uploadSessionService.requestPresignedUrl(
        chunk.sessionId,
        chunk.sequence,
      );
      final file = File(chunk.filePath);
      if (!await file.exists()) {
        logger.w('Chunk file missing on disk: ${chunk.filePath}');
        await chunkStore.deleteChunk(chunk.id);
        return;
      }
      final bytes = await file.readAsBytes();
      await uploadSessionService.uploadChunk(
        presigned.url,
        bytes,
        headers: presigned.headers,
      );
      await uploadSessionService.notifyChunkUploaded(
        chunk.sessionId,
        chunk.sequence,
      );
      await chunkStore.markUploaded(chunk.id);
      await chunkStore.deleteChunk(chunk.id);
      logger.i('Uploaded chunk ${chunk.id}');
    } catch (error, stackTrace) {
      logger.w('Failed to upload chunk ${chunk.id}', error, stackTrace);
      await chunkStore.incrementRetry(chunk.id);
    }
  }
}
