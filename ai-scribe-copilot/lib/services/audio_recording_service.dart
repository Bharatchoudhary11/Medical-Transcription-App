import 'dart:async';
import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/permission_utils.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import '../models/audio_chunk.dart';
import '../models/recording_session.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';
import 'local_storage_service.dart';

class AudioRecordingService {
  static final AudioRecordingService _instance = AudioRecordingService._internal();
  factory AudioRecordingService() => _instance;
  AudioRecordingService._internal();

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final ApiService _apiService = ApiService();
  final LocalStorageService _storageService = LocalStorageService();
  final Connectivity _connectivity = Connectivity();
  final Uuid _uuid = const Uuid();

  Timer? _chunkTimer;
  Timer? _retryTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  RecordingSession? _currentSession;
  int _chunkSequence = 0;
  bool _isRecording = false;
  bool _isPaused = false;
  String? _currentRecordingPath;
  bool _isInitialized = false;
  
  final StreamController<RecordingSession> _sessionController = 
      StreamController<RecordingSession>.broadcast();
  final StreamController<AudioChunk> _chunkController = 
      StreamController<AudioChunk>.broadcast();
  final StreamController<double> _amplitudeController = 
      StreamController<double>.broadcast();

  // Getters
  bool get isRecording => _isRecording;
  bool get isPaused => _isPaused;
  RecordingSession? get currentSession => _currentSession;
  
  // Streams
  Stream<RecordingSession> get sessionStream => _sessionController.stream;
  Stream<AudioChunk> get chunkStream => _chunkController.stream;
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  Future<bool> initialize() async {
    try {
      await _ensureMicrophonePermissionGranted();
      await _ensureRecorderInitialized();

      // Set up connectivity monitoring
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        (results) => _onConnectivityChanged(results.first),
      );

      return true;
    } catch (e) {
      print('Failed to initialize audio recording service: $e');
      return false;
    }
  }

  Future<bool> startRecording(String patientId, String userId) async {
    if (_isRecording) {
      throw Exception('Recording already in progress');
    }

    try {
      await _ensureMicrophonePermissionGranted();
      await _ensureRecorderInitialized();

      // Create new session
      _currentSession = RecordingSession(
        id: _uuid.v4(),
        patientId: patientId,
        userId: userId,
        status: RecordingStatus.recording,
        startTime: DateTime.now(),
        totalChunks: 0,
        uploadedChunks: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save session to local storage
      await _storageService.saveSession(_currentSession!);
      _sessionController.add(_currentSession!);

      // Start recording
      final directory = await getApplicationDocumentsDirectory();
      _currentRecordingPath = '${directory.path}/recording_${_currentSession!.id}.aac';
      
      await _recorder.startRecorder(
        toFile: _currentRecordingPath!,
        codec: Codec.aacADTS,
        sampleRate: ApiConstants.sampleRate,
        bitRate: ApiConstants.bitRate,
      );

      _isRecording = true;
      _isPaused = false;
      _chunkSequence = 0;

      // Start chunking timer
      _startChunkTimer();

      // Start amplitude monitoring
      _startAmplitudeMonitoring();

      return true;
    } catch (e) {
      print('Failed to start recording: $e');
      return false;
    }
  }

  Future<void> _ensureMicrophonePermissionGranted() async {
    final status = await Permission.microphone.status;
    if (hasMicrophoneAccess(status)) {
      return;
    }

    final result = await Permission.microphone.request();
    if (!hasMicrophoneAccess(result)) {
      throw Exception('Microphone permission denied');
    }
  }

  Future<void> _ensureRecorderInitialized() async {
    if (_isInitialized) {
      return;
    }

    await _recorder.openRecorder();
    _isInitialized = true;
  }

  Future<bool> pauseRecording() async {
    if (!_isRecording || _isPaused) return false;

    try {
      await _recorder.pauseRecorder();
      _isPaused = true;
      
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          status: RecordingStatus.paused,
          updatedAt: DateTime.now(),
        );
        await _storageService.saveSession(_currentSession!);
        _sessionController.add(_currentSession!);
      }

      return true;
    } catch (e) {
      print('Failed to pause recording: $e');
      return false;
    }
  }

  Future<bool> resumeRecording() async {
    if (!_isRecording || !_isPaused) return false;

    try {
      await _recorder.resumeRecorder();
      _isPaused = false;
      
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          status: RecordingStatus.recording,
          updatedAt: DateTime.now(),
        );
        await _storageService.saveSession(_currentSession!);
        _sessionController.add(_currentSession!);
      }

      return true;
    } catch (e) {
      print('Failed to resume recording: $e');
      return false;
    }
  }

  Future<bool> stopRecording() async {
    if (!_isRecording) return false;

    try {
      // Stop chunking timer
      _chunkTimer?.cancel();
      _retryTimer?.cancel();

      // Stop recording
      await _recorder.stopRecorder();
      _isRecording = false;
      _isPaused = false;

      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          status: RecordingStatus.completed,
          endTime: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _storageService.saveSession(_currentSession!);
        _sessionController.add(_currentSession!);
      }

      // Upload any remaining chunks
      await _uploadPendingChunks();

      return true;
    } catch (e) {
      print('Failed to stop recording: $e');
      return false;
    }
  }

  void _startChunkTimer() {
    _chunkTimer = Timer.periodic(
      const Duration(milliseconds: ApiConstants.chunkSizeMs),
      (timer) => _createChunk(),
    );
  }

  void _startAmplitudeMonitoring() {
    _recorder.onProgress!.listen((event) {
      _amplitudeController.add(event.decibels ?? 0.0);
    });
  }

  Future<void> _createChunk() async {
    if (!_isRecording || _isPaused || _currentSession == null) return;

    try {
      // Create chunk file
      final chunkId = _uuid.v4();
      final chunkPath = '${_currentRecordingPath!}_chunk_${_chunkSequence}.aac';
      
      // For now, we'll create a placeholder chunk
      // In a real implementation, you'd extract the audio data for this time period
      final chunk = AudioChunk(
        id: chunkId,
        sessionId: _currentSession!.id,
        sequenceNumber: _chunkSequence,
        filePath: chunkPath,
        sizeBytes: 0, // Will be updated when file is created
        duration: const Duration(milliseconds: ApiConstants.chunkSizeMs),
        timestamp: DateTime.now(),
        status: ChunkStatus.pending,
        retryCount: 0,
      );

      _chunkSequence++;
      
      // Update session
      _currentSession = _currentSession!.copyWith(
        totalChunks: _currentSession!.totalChunks + 1,
        updatedAt: DateTime.now(),
      );

      // Save chunk to local storage
      await _storageService.saveChunk(chunk);
      _chunkController.add(chunk);

      // Try to upload chunk immediately
      await _uploadChunk(chunk);

    } catch (e) {
      print('Failed to create chunk: $e');
    }
  }

  Future<void> _uploadChunk(AudioChunk chunk) async {
    try {
      // Check connectivity
      final connectivityResults = await _connectivity.checkConnectivity();
      if (connectivityResults.first == ConnectivityResult.none) {
        // Queue for later upload
        return;
      }

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
        status: ChunkStatus.uploading,
      );
      await _storageService.saveChunk(updatedChunk);

      // Upload file
      final file = File(chunk.filePath);
      if (await file.exists()) {
        await _apiService.uploadChunk(presignedUrl, file);
        
        // Notify backend
        await _apiService.notifyChunkUploaded(chunk.sessionId, chunk.sequenceNumber);
        
        // Update chunk status
        final completedChunk = updatedChunk.copyWith(
          status: ChunkStatus.uploaded,
          uploadedAt: DateTime.now(),
        );
        await _storageService.saveChunk(completedChunk);
        
        // Update session
        if (_currentSession != null) {
          _currentSession = _currentSession!.copyWith(
            uploadedChunks: _currentSession!.uploadedChunks + 1,
            updatedAt: DateTime.now(),
          );
          await _storageService.saveSession(_currentSession!);
          _sessionController.add(_currentSession!);
        }
      }
    } catch (e) {
      print('Failed to upload chunk: $e');
      await _handleChunkUploadFailure(chunk);
    }
  }

  Future<void> _handleChunkUploadFailure(AudioChunk chunk) async {
    final updatedChunk = chunk.copyWith(
      retryCount: chunk.retryCount + 1,
      status: chunk.retryCount >= ApiConstants.maxRetryAttempts 
          ? ChunkStatus.failed 
          : ChunkStatus.pending,
    );
    
    await _storageService.saveChunk(updatedChunk);
    
    if (updatedChunk.status == ChunkStatus.pending) {
      // Schedule retry
      Timer(Duration(milliseconds: ApiConstants.retryDelayMs), () {
        _uploadChunk(updatedChunk);
      });
    }
  }

  Future<void> _uploadPendingChunks() async {
    final pendingChunks = await _storageService.getPendingChunks();
    for (final chunk in pendingChunks) {
      await _uploadChunk(chunk);
    }
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    if (result != ConnectivityResult.none) {
      // Network is back, try to upload pending chunks
      _uploadPendingChunks();
    }
  }

  Future<void> dispose() async {
    _chunkTimer?.cancel();
    _retryTimer?.cancel();
    _connectivitySubscription?.cancel();
    await _recorder.closeRecorder();
    await _sessionController.close();
    await _chunkController.close();
    await _amplitudeController.close();
  }
}
