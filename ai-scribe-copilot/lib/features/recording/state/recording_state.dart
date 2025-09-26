enum RecordingLifecycle { idle, preparing, recording, paused, error }

enum NetworkStatus { online, offline }

enum BatteryStatus { healthy, critical }

class RecordingState {
  const RecordingState({
    this.lifecycle = RecordingLifecycle.idle,
    this.duration = Duration.zero,
    this.networkStatus = NetworkStatus.online,
    this.batteryStatus,
    this.sessionId,
    this.patientName,
    this.errorMessage,
  });

  final RecordingLifecycle lifecycle;
  final Duration duration;
  final NetworkStatus networkStatus;
  final BatteryStatus? batteryStatus;
  final String? sessionId;
  final String? patientName;
  final String? errorMessage;

  RecordingState copyWith({
    RecordingLifecycle? lifecycle,
    Duration? duration,
    NetworkStatus? networkStatus,
    BatteryStatus? batteryStatus,
    String? sessionId,
    String? patientName,
    String? errorMessage,
  }) {
    return RecordingState(
      lifecycle: lifecycle ?? this.lifecycle,
      duration: duration ?? this.duration,
      networkStatus: networkStatus ?? this.networkStatus,
      batteryStatus: batteryStatus ?? this.batteryStatus,
      sessionId: sessionId ?? this.sessionId,
      patientName: patientName ?? this.patientName,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
