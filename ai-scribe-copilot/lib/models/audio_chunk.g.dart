// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_chunk.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AudioChunk _$AudioChunkFromJson(Map<String, dynamic> json) => AudioChunk(
  id: json['id'] as String,
  sessionId: json['sessionId'] as String,
  sequenceNumber: (json['sequenceNumber'] as num).toInt(),
  filePath: json['filePath'] as String,
  sizeBytes: (json['sizeBytes'] as num).toInt(),
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
  timestamp: DateTime.parse(json['timestamp'] as String),
  status: $enumDecode(_$ChunkStatusEnumMap, json['status']),
  presignedUrl: json['presignedUrl'] as String?,
  uploadedAt: json['uploadedAt'] == null
      ? null
      : DateTime.parse(json['uploadedAt'] as String),
  retryCount: (json['retryCount'] as num).toInt(),
);

Map<String, dynamic> _$AudioChunkToJson(AudioChunk instance) =>
    <String, dynamic>{
      'id': instance.id,
      'sessionId': instance.sessionId,
      'sequenceNumber': instance.sequenceNumber,
      'filePath': instance.filePath,
      'sizeBytes': instance.sizeBytes,
      'duration': instance.duration.inMicroseconds,
      'timestamp': instance.timestamp.toIso8601String(),
      'status': _$ChunkStatusEnumMap[instance.status]!,
      'presignedUrl': instance.presignedUrl,
      'uploadedAt': instance.uploadedAt?.toIso8601String(),
      'retryCount': instance.retryCount,
    };

const _$ChunkStatusEnumMap = {
  ChunkStatus.pending: 'pending',
  ChunkStatus.uploading: 'uploading',
  ChunkStatus.uploaded: 'uploaded',
  ChunkStatus.failed: 'failed',
};
