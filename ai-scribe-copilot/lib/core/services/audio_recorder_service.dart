import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';

import '../../utils/logger.dart';
import '../models/recording_chunk.dart';
import 'chunk_persistence_service.dart';
import 'interruption_handler.dart';

class AudioRecorderService {
  AudioRecorderService({
    required this.logger,
    required this.chunkPersistenceService,
    required this.interruptionHandler,
    this.chunkSizeBytes = 16000 * 2 * 5,
  })  : _recorder = FlutterSoundRecorder(),
        _chunkStreamController = StreamController<RecordingChunk>.broadcast();

  final Logger logger;
  final ChunkPersistenceService chunkPersistenceService;
  final InterruptionHandler interruptionHandler;
  final int chunkSizeBytes;
  final FlutterSoundRecorder _recorder;
  final StreamController<RecordingChunk> _chunkStreamController;
  StreamSubscription<RecordingDisposition>? _recordingSubscription;
  StreamController<Uint8List>? _pcmStreamController;
  StreamSubscription<Uint8List>? _pcmStreamSubscription;
  String? _activeSessionId;
  int _chunkSequence = 0;
  final List<int> _buffer = <int>[];
  bool _initialized = false;

  Stream<RecordingChunk> get chunkStream => _chunkStreamController.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    await _recorder.openRecorder();
    _initialized = true;
  }

  Future<void> dispose() async {
    await _recordingSubscription?.cancel();
    await _pcmStreamSubscription?.cancel();
    await _pcmStreamController?.close();
    await _recorder.closeRecorder();
    await _chunkStreamController.close();
  }

  bool get isRecording => _recorder.isRecording;

  Future<void> startRecording(String sessionId, {bool resetSequence = false}) async {
    if (!_initialized) {
      await initialize();
    }
    if (resetSequence) {
      _chunkSequence = 0;
    }
    _buffer.clear();
    _activeSessionId = sessionId;
    await interruptionHandler.requestAudioFocus();
    await interruptionHandler.setGain(1.2);
    final directory = await getTemporaryDirectory();
    _recordingSubscription?.cancel();
    _recordingSubscription = _recorder.onProgress?.listen(_onProgress);
    await _pcmStreamSubscription?.cancel();
    await _pcmStreamController?.close();
    _pcmStreamController = StreamController<Uint8List>();
    _pcmStreamSubscription = _pcmStreamController!.stream.listen((data) {
      _buffer.addAll(data);
      if (_buffer.length >= chunkSizeBytes) {
        unawaited(_flushBuffer(directory));
      }
    });
    await _recorder.startRecorder(
      toStream: _pcmStreamController!.sink,
      codec: Codec.pcm16,
      numChannels: 1,
      sampleRate: 16000,
    );
    logger.i('Recording started for session $sessionId');
  }

  void _onProgress(RecordingDisposition disposition) {
    logger.d('Recording level: ${disposition.decibels}');
  }

  Future<void> _flushBuffer(Directory directory) async {
    final sessionId = _activeSessionId;
    if (sessionId == null || _buffer.isEmpty) {
      return;
    }
    final file = File('${directory.path}/chunk_${DateTime.now().microsecondsSinceEpoch}.pcm');
    await file.writeAsBytes(_buffer.toList(), flush: true);
    _buffer.clear();
    final chunk = await chunkPersistenceService.addChunk(
      sessionId: sessionId,
      sequence: _chunkSequence++,
      filePath: file.path,
    );
    _chunkStreamController.add(chunk);
  }

  Future<void> stopRecording({bool flushRemaining = true, bool clearSession = true}) async {
    if (!_recorder.isRecording) return;
    await _recorder.stopRecorder();
    await interruptionHandler.abandonAudioFocus();
    if (flushRemaining) {
      final directory = await getTemporaryDirectory();
      await _flushBuffer(directory);
    } else {
      _buffer.clear();
    }
    await _pcmStreamSubscription?.cancel();
    _pcmStreamSubscription = null;
    await _pcmStreamController?.close();
    _pcmStreamController = null;
    logger.i('Recording stopped for session $_activeSessionId');
    if (clearSession) {
      _activeSessionId = null;
    }
  }

  Future<void> handleInterruption(InterruptionEvent event) async {
    if (event.type == InterruptionEventType.phoneCallStarted ||
        event.type == InterruptionEventType.audioFocusLost) {
      if (_recorder.isRecording && _activeSessionId != null) {
        await stopRecording(flushRemaining: false, clearSession: false);
      }
    } else if (event.type == InterruptionEventType.phoneCallEnded ||
        event.type == InterruptionEventType.audioFocusGained) {
      if (_activeSessionId != null && !_recorder.isRecording) {
        await startRecording(_activeSessionId!);
      }
    }
  }
}
