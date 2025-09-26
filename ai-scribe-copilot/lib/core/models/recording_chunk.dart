import 'dart:convert';

class RecordingChunk {
  RecordingChunk({
    required this.id,
    required this.sessionId,
    required this.sequence,
    required this.filePath,
    required this.createdAt,
    this.uploadedAt,
    this.retryCount = 0,
  });

  final String id;
  final String sessionId;
  final int sequence;
  final String filePath;
  final DateTime createdAt;
  final DateTime? uploadedAt;
  final int retryCount;

  RecordingChunk copyWith({
    DateTime? uploadedAt,
    int? retryCount,
  }) {
    return RecordingChunk(
      id: id,
      sessionId: sessionId,
      sequence: sequence,
      filePath: filePath,
      createdAt: createdAt,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      retryCount: retryCount ?? this.retryCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sessionId': sessionId,
      'sequence': sequence,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'uploadedAt': uploadedAt?.toIso8601String(),
      'retryCount': retryCount,
    };
  }

  factory RecordingChunk.fromJson(Map<String, dynamic> json) {
    return RecordingChunk(
      id: json['id'] as String,
      sessionId: json['sessionId'] as String,
      sequence: json['sequence'] as int,
      filePath: json['filePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      uploadedAt: json['uploadedAt'] != null
          ? DateTime.parse(json['uploadedAt'] as String)
          : null,
      retryCount: json['retryCount'] as int,
    );
  }

  @override
  String toString() => jsonEncode(toJson());
}
