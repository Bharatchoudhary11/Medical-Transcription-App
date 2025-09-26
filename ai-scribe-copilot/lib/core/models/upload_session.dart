class UploadSession {
  UploadSession({
    required this.sessionId,
    required this.patientId,
    required this.userId,
    required this.startedAt,
  });

  final String sessionId;
  final String patientId;
  final String userId;
  final DateTime startedAt;
}
