import '../../utils/logger.dart';
import '../models/upload_session.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class PresignedUrl {
  PresignedUrl({required this.url, required this.headers});

  final String url;
  final Map<String, dynamic> headers;
}

class UploadSessionService {
  UploadSessionService({required this.apiClient, required this.logger});

  final ApiClient apiClient;
  final Logger logger;

  Future<UploadSession> startSession({
    required String patientId,
    required String userId,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.startSession,
      data: {
        'patientId': patientId,
        'userId': userId,
      },
    );
    final sessionId = response['sessionId'] as String;
    return UploadSession(
      sessionId: sessionId,
      patientId: patientId,
      userId: userId,
      startedAt: DateTime.now().toUtc(),
    );
  }

  Future<PresignedUrl> requestPresignedUrl(String sessionId, int sequence) async {
    final response = await apiClient.post(
      ApiEndpoints.presignedUrl,
      data: {
        'sessionId': sessionId,
        'sequence': sequence,
      },
    );
    return PresignedUrl(
      url: response['url'] as String,
      headers: response['headers'] != null
          ? Map<String, dynamic>.from(response['headers'] as Map)
          : const {},
    );
  }

  Future<void> uploadChunk(String url, List<int> bytes, {Map<String, dynamic>? headers}) async {
    await apiClient.putRaw(url, data: bytes, headers: headers);
  }

  Future<void> notifyChunkUploaded(String sessionId, int sequence) async {
    await apiClient.post(
      ApiEndpoints.notifyChunkUploaded,
      data: {
        'sessionId': sessionId,
        'sequence': sequence,
      },
    );
  }
}
