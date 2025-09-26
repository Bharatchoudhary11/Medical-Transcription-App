import 'package:json_annotation/json_annotation.dart';

part 'audio_chunk.g.dart';

@JsonSerializable()
class AudioChunk {
  final String id;
  final String sessionId;
  final int sequenceNumber;
  final String filePath;
  final int sizeBytes;
  final Duration duration;
  final DateTime timestamp;
  final ChunkStatus status;
  final String? presignedUrl;
  final DateTime? uploadedAt;
  final int retryCount;

  const AudioChunk({
    required this.id,
    required this.sessionId,
    required this.sequenceNumber,
    required this.filePath,
    required this.sizeBytes,
    required this.duration,
    required this.timestamp,
    required this.status,
    this.presignedUrl,
    this.uploadedAt,
    required this.retryCount,
  });

  factory AudioChunk.fromJson(Map<String, dynamic> json) => 
      _$AudioChunkFromJson(json);
  Map<String, dynamic> toJson() => _$AudioChunkToJson(this);

  AudioChunk copyWith({
    String? id,
    String? sessionId,
    int? sequenceNumber,
    String? filePath,
    int? sizeBytes,
    Duration? duration,
    DateTime? timestamp,
    ChunkStatus? status,
    String? presignedUrl,
    DateTime? uploadedAt,
    int? retryCount,
  }) {
    return AudioChunk(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      presignedUrl: presignedUrl ?? this.presignedUrl,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

enum ChunkStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('uploading')
  uploading,
  @JsonValue('uploaded')
  uploaded,
  @JsonValue('failed')
  failed,
}
