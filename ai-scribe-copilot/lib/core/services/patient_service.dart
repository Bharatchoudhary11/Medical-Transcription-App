import 'package:dio/dio.dart';

import '../../utils/logger.dart';
import '../models/patient.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class PatientService {
  PatientService({required this.apiClient, required this.logger});

  final ApiClient apiClient;
  final Logger logger;

  Future<List<Patient>> fetchPatients(String userId) async {
    try {
      final response = await apiClient.get(
        ApiEndpoints.patients,
        queryParameters: {'userId': userId},
      );
      final data = response['patients'] as List<dynamic>? ?? const [];
      return data
          .map((e) => Patient.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on DioException catch (error, stackTrace) {
      logger.e('Failed to fetch patients', error, stackTrace);
      final connectionIssues = error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout;
      final message = connectionIssues
          ? 'Unable to reach the backend at ${ApiEndpoints.baseUrl}. '
              'Ensure the API server is running and accessible from your simulator or device.'
          : error.message ?? 'Unexpected error communicating with the backend.';
      throw Exception(message);
    }
  }

  Future<Patient> addPatient({
    required String name,
    required DateTime? dateOfBirth,
    required String? mrn,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.addPatient,
      data: {
        'name': name,
        if (dateOfBirth != null) 'dateOfBirth': dateOfBirth.toIso8601String(),
        if (mrn != null) 'mrn': mrn,
      },
    );
    final payload = response['patient'];
    if (payload is Map) {
      return Patient.fromJson(
        Map<String, dynamic>.from(payload as Map<dynamic, dynamic>),
      );
    }

    if (response.isNotEmpty) {
      return Patient.fromJson(
        Map<String, dynamic>.from(response as Map<dynamic, dynamic>),
      );
    }

    throw StateError('Invalid response when adding patient: $response');
  }
}
