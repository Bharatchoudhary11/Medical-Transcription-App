import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/models/upload_session.dart';
import '../../../core/services/audio_recorder_service.dart';
import '../../../core/services/chunk_uploader.dart';
import '../../../core/services/connectivity_monitor.dart';
import '../../../core/services/interruption_handler.dart';
import '../../../core/services/upload_session_service.dart';
import '../../../shared/providers.dart';
import '../../../utils/logger.dart';
import '../../../utils/permission_utils.dart';
import '../state/recording_state.dart';

final recordingControllerProvider =
    StateNotifierProvider<RecordingController, RecordingState>(
  (ref) {
    final recorder = ref.watch(audioRecorderServiceProvider);
    final uploader = ref.watch(chunkUploaderProvider);
    final uploadService = ref.watch(uploadSessionServiceProvider);
    final connectivity = ref.watch(connectivityMonitorProvider);
    final interruption = ref.watch(interruptionHandlerProvider);
    final logger = ref.watch(loggerProvider);
    final controller = RecordingController(
      recorder: recorder,
      uploader: uploader,
      uploadSessionService: uploadService,
      connectivityMonitor: connectivity,
      interruptionHandler: interruption,
      logger: logger,
    );
    uploader.bindToRecorder(recorder.chunkStream);
    return controller;
  },
);

class RecordingController extends StateNotifier<RecordingState> {
  RecordingController({
    required this.recorder,
    required this.uploader,
    required this.uploadSessionService,
    required this.connectivityMonitor,
    required this.interruptionHandler,
    required this.logger,
  }) : super(const RecordingState()) {
    _battery = Battery();
    _connectivitySub = connectivityMonitor.onlineStream.listen((online) {
      state = state.copyWith(
        networkStatus: online ? NetworkStatus.online : NetworkStatus.offline,
      );
    });
    _interruptionSub = interruptionHandler.events.listen((event) {
      recorder.handleInterruption(event);
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  final AudioRecorderService recorder;
  final ChunkUploader uploader;
  final UploadSessionService uploadSessionService;
  final ConnectivityMonitor connectivityMonitor;
  final InterruptionHandler interruptionHandler;
  final Logger logger;

  late final Battery _battery;
  StreamSubscription<bool>? _connectivitySub;
  StreamSubscription? _interruptionSub;
  Timer? _tickTimer;
  UploadSession? _session;
  DateTime? _startedAt;

  Future<void> start(String patientId, String patientName, String userId) async {
    state = state.copyWith(lifecycle: RecordingLifecycle.preparing, patientName: patientName);
    try {
      final currentStatus = await Permission.microphone.status;
      final micStatus = hasMicrophoneAccess(currentStatus)
          ? currentStatus
          : await Permission.microphone.request();
      if (!hasMicrophoneAccess(micStatus)) {
        state = state.copyWith(
          lifecycle: RecordingLifecycle.error,
          errorMessage: 'Microphone permission is required to record.',
        );
        return;
      }
      final batteryLevel = await _battery.batteryLevel;
      state = state.copyWith(
        batteryStatus: batteryLevel < 20 ? BatteryStatus.critical : BatteryStatus.healthy,
      );
      _session = await uploadSessionService.startSession(
        patientId: patientId,
        userId: userId,
      );
      state = state.copyWith(sessionId: _session!.sessionId);
      await uploader.startSession(_session!);
      await recorder.startRecording(_session!.sessionId, resetSequence: true);
      state = state.copyWith(lifecycle: RecordingLifecycle.recording);
      _startedAt = DateTime.now();
    } catch (error, stackTrace) {
      logger.e('Failed to start recording', error, stackTrace);
      state = state.copyWith(
        lifecycle: RecordingLifecycle.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> pause() async {
    if (!recorder.isRecording) return;
    await recorder.stopRecording(clearSession: false);
    state = state.copyWith(lifecycle: RecordingLifecycle.paused);
  }

  Future<void> resume() async {
    final session = _session;
    if (session == null) return;
    await recorder.startRecording(session.sessionId);
    state = state.copyWith(lifecycle: RecordingLifecycle.recording);
  }

  Future<void> stop() async {
    await recorder.stopRecording();
    await uploader.stopSession();
    state = state.copyWith(
      lifecycle: RecordingLifecycle.idle,
      duration: Duration.zero,
      sessionId: null,
    );
    _session = null;
    _startedAt = null;
  }

  void _onTick(Timer timer) {
    if (state.lifecycle == RecordingLifecycle.recording && _startedAt != null) {
      final duration = DateTime.now().difference(_startedAt!);
      state = state.copyWith(duration: duration);
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _interruptionSub?.cancel();
    _tickTimer?.cancel();
    super.dispose();
  }
}
