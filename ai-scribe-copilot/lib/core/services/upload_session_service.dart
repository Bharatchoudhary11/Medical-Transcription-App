import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;

import '../../utils/logger.dart';
import '../models/upload_session.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class PresignedUploadRequest {
  PresignedUploadRequest({
    required this.url,
    required this.method,
    required this.headers,
    required this.fields,
    required this.fileFieldName,
    this.fileName,
    this.requiresMultipart = false,
    this.gcsPath,
    this.publicUrl,
    this.mimeType,
  });

  final String url;
  final String method;
  final Map<String, dynamic> headers;
  final Map<String, dynamic> fields;
  final String fileFieldName;
  final String? fileName;
  final bool requiresMultipart;
  final String? gcsPath;
  final String? publicUrl;
  final String? mimeType;
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
    final rawSessionId =
        (response['sessionId'] ?? response['id'])?.toString().trim();
    if (rawSessionId == null || rawSessionId.isEmpty) {
      throw StateError(
        'Upload session response did not include a session identifier.',
      );
    }
    return UploadSession(
      sessionId: rawSessionId,
      patientId: patientId,
      userId: userId,
      startedAt: DateTime.now().toUtc(),
    );
  }

  Future<PresignedUploadRequest> requestPresignedUrl(
    String sessionId,
    int sequence, {
    String? mimeType,
  }) async {
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'chunkNumber': sequence,
    };
    if (mimeType != null && mimeType.isNotEmpty) {
      payload['mimeType'] = mimeType;
    }
    final response = await apiClient.post(
      ApiEndpoints.presignedUrl,
      data: payload,
    );

    final rawUrl = (response['url'] ?? response['presignedUrl'] ??
            response['uploadUrl'] ?? response['signedUrl'])
        ?.toString()
        .trim();
    if (rawUrl == null || rawUrl.isEmpty) {
      throw StateError('Presigned URL response did not include an upload URL.');
    }

    final method = (response['method'] as String? ?? 'PUT').toUpperCase();
    final headers = _normaliseMap(response['headers']);
    final fields = _normaliseMap(response['fields']);
    final inferredFileFieldName = response['fileFieldName']?.toString().trim();
    final defaultFieldName = inferredFileFieldName?.isNotEmpty == true
        ? inferredFileFieldName!
        : rawUrl.contains('/api/upload-chunk/')
            ? 'audio'
            : 'file';

    final requiresMultipart = response['requiresMultipart'] == true ||
        response['requiresFormData'] == true ||
        fields.isNotEmpty ||
        method == 'POST' ||
        (response.containsKey('presignedUrl') && !response.containsKey('url'));

    return PresignedUploadRequest(
      url: rawUrl,
      method: method,
      headers: headers,
      fields: fields,
      fileFieldName: defaultFieldName,
      fileName: response['fileName']?.toString(),
      requiresMultipart: requiresMultipart,
      gcsPath: response['gcsPath']?.toString(),
      publicUrl: response['publicUrl']?.toString(),
      mimeType: mimeType ?? response['mimeType']?.toString(),
    );
  }

  Future<void> uploadChunk(
    PresignedUploadRequest request,
    File file,
  ) async {
    final method = request.method;
    logger.d(
      'Uploading chunk to ${request.url} using $method (multipart: ${request.requiresMultipart}).',
    );

    if (request.requiresMultipart) {
      final bytes = await file.readAsBytes();
      final filename = request.fileName ?? path.basename(file.path);
      final formFields = Map<String, dynamic>.from(request.fields);
      formFields[request.fileFieldName] = MultipartFile.fromBytes(
        bytes,
        filename: filename,
      );
      final formData = FormData.fromMap(formFields);
      await apiClient.send(
        method,
        request.url,
        data: formData,
        headers: request.headers.isEmpty ? null : request.headers,
      );
      return;
    }

    final bytes = await file.readAsBytes();
    await apiClient.uploadRaw(
      request.url,
      bytes,
      method: method,
      headers: request.headers.isEmpty ? null : request.headers,
    );
  }

  Future<void> notifyChunkUploaded(
    String sessionId,
    int chunkNumber, {
    PresignedUploadRequest? request,
    bool? isLast,
    int? totalChunksClient,
  }) async {
    final payload = <String, dynamic>{
      'sessionId': sessionId,
      'chunkNumber': chunkNumber,
    };
    if (request?.gcsPath != null) {
      payload['gcsPath'] = request!.gcsPath;
    }
    if (request?.publicUrl != null) {
      payload['publicUrl'] = request!.publicUrl;
    }
    if (request?.mimeType != null) {
      payload['mimeType'] = request!.mimeType;
    }
    if (isLast != null) {
      payload['isLast'] = isLast;
    }
    if (totalChunksClient != null) {
      payload['totalChunksClient'] = totalChunksClient;
    }

    await apiClient.post(
      ApiEndpoints.notifyChunkUploaded,
      data: payload,
    );
  }

  Map<String, dynamic> _normaliseMap(dynamic source) {
    if (source is Map) {
      return source.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }
}
