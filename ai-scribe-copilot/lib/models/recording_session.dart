import 'package:json_annotation/json_annotation.dart';

part 'recording_session.g.dart';

@JsonSerializable()
class RecordingSession {
  final String id;
  final String patientId;
  final String userId;
  final RecordingStatus status;
  final DateTime startTime;
  final DateTime? endTime;
  final int totalChunks;
  final int uploadedChunks;
  final String? transcription;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RecordingSession({
    required this.id,
    required this.patientId,
    required this.userId,
    required this.status,
    required this.startTime,
    this.endTime,
    required this.totalChunks,
    required this.uploadedChunks,
    this.transcription,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RecordingSession.fromJson(Map<String, dynamic> json) => 
      _$RecordingSessionFromJson(json);
  Map<String, dynamic> toJson() => _$RecordingSessionToJson(this);

  RecordingSession copyWith({
    String? id,
    String? patientId,
    String? userId,
    RecordingStatus? status,
    DateTime? startTime,
    DateTime? endTime,
    int? totalChunks,
    int? uploadedChunks,
    String? transcription,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RecordingSession(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      userId: userId ?? this.userId,
      status: status ?? this.status,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      totalChunks: totalChunks ?? this.totalChunks,
      uploadedChunks: uploadedChunks ?? this.uploadedChunks,
      transcription: transcription ?? this.transcription,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

enum RecordingStatus {
  @JsonValue('recording')
  recording,
  @JsonValue('paused')
  paused,
  @JsonValue('completed')
  completed,
  @JsonValue('failed')
  failed,
}
