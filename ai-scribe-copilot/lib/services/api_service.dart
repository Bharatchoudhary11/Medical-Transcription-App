import 'dart:io';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/patient.dart';
import '../models/recording_session.dart';
import '../constants/api_constants.dart';

class ApiService {
  late final Dio _dio;
  final Connectivity _connectivity = Connectivity();

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ));

    // Add interceptors for logging and error handling
    _dio.interceptors.add(LogInterceptor(
      requestBody: true,
      responseBody: true,
      error: true,
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Handle authentication error
          print('Authentication error: ${error.response?.data}');
        }
        handler.next(error);
      },
    ));
  }

  Future<bool> _checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return results.first != ConnectivityResult.none;
  }

  // Session Management
  Future<String?> createUploadSession(String patientId, String userId) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.post(
        ApiConstants.uploadSession,
        data: {
          'patientId': patientId,
          'userId': userId,
        },
      );

      if (response.statusCode == 200) {
        return response.data['sessionId'] as String?;
      }
      return null;
    } catch (e) {
      print('Failed to create upload session: $e');
      rethrow;
    }
  }

  Future<String?> getPresignedUrl(String sessionId, int chunkNumber) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.post(
        ApiConstants.getPresignedUrl,
        data: {
          'sessionId': sessionId,
          'chunkNumber': chunkNumber,
        },
      );

      if (response.statusCode == 200) {
        return response.data['presignedUrl'] as String?;
      }
      return null;
    } catch (e) {
      print('Failed to get presigned URL: $e');
      rethrow;
    }
  }

  Future<bool> notifyChunkUploaded(String sessionId, int chunkNumber) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.post(
        ApiConstants.notifyChunkUploaded,
        data: {
          'sessionId': sessionId,
          'chunkNumber': chunkNumber,
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to notify chunk uploaded: $e');
      return false;
    }
  }

  Future<bool> uploadChunk(String presignedUrl, File file) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.put(
        presignedUrl,
        data: file.openRead(),
        options: Options(
          headers: {
            'Content-Type': 'audio/aac',
          },
        ),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Failed to upload chunk: $e');
      rethrow;
    }
  }

  // Patient Management
  Future<List<Patient>> getPatients(String userId) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.get(
        ApiConstants.patients,
        queryParameters: {'userId': userId},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['patients'] ?? [];
        return data.map((json) => Patient.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Failed to get patients: $e');
      return [];
    }
  }

  Future<Patient?> addPatient(Patient patient) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.post(
        ApiConstants.addPatient,
        data: patient.toJson(),
      );

      if (response.statusCode == 200) {
        return Patient.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Failed to add patient: $e');
      return null;
    }
  }

  Future<List<RecordingSession>> getSessionsByPatient(String patientId) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.get(
        '${ApiConstants.fetchSessionByPatient}/$patientId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['sessions'] ?? [];
        return data.map((json) => RecordingSession.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Failed to get sessions by patient: $e');
      return [];
    }
  }

  Future<String?> getTranscription(String sessionId) async {
    if (!await _checkConnectivity()) {
      throw Exception('No internet connection');
    }

    try {
      final response = await _dio.get(
        '/v1/transcription/$sessionId',
      );

      if (response.statusCode == 200) {
        return response.data['transcription'] as String?;
      }
      return null;
    } catch (e) {
      print('Failed to get transcription: $e');
      return null;
    }
  }
}
