// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_session.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RecordingSession _$RecordingSessionFromJson(Map<String, dynamic> json) =>
    RecordingSession(
      id: json['id'] as String,
      patientId: json['patientId'] as String,
      userId: json['userId'] as String,
      status: $enumDecode(_$RecordingStatusEnumMap, json['status']),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] == null
          ? null
          : DateTime.parse(json['endTime'] as String),
      totalChunks: (json['totalChunks'] as num).toInt(),
      uploadedChunks: (json['uploadedChunks'] as num).toInt(),
      transcription: json['transcription'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$RecordingSessionToJson(RecordingSession instance) =>
    <String, dynamic>{
      'id': instance.id,
      'patientId': instance.patientId,
      'userId': instance.userId,
      'status': _$RecordingStatusEnumMap[instance.status]!,
      'startTime': instance.startTime.toIso8601String(),
      'endTime': instance.endTime?.toIso8601String(),
      'totalChunks': instance.totalChunks,
      'uploadedChunks': instance.uploadedChunks,
      'transcription': instance.transcription,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
    };

const _$RecordingStatusEnumMap = {
  RecordingStatus.recording: 'recording',
  RecordingStatus.paused: 'paused',
  RecordingStatus.completed: 'completed',
  RecordingStatus.failed: 'failed',
};
