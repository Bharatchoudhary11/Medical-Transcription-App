import '../../utils/logger.dart';
import '../models/patient.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';

class PatientService {
  PatientService({required this.apiClient, required this.logger});

  final ApiClient apiClient;
  final Logger logger;

  Future<List<Patient>> fetchPatients(String userId) async {
    final response = await apiClient.get(
      ApiEndpoints.patients,
      queryParameters: {'userId': userId},
    );
    final data = response['patients'] as List<dynamic>? ?? const [];
    return data.map((e) => Patient.fromJson(Map<String, dynamic>.from(e as Map))).toList();
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
    return Patient.fromJson(Map<String, dynamic>.from(response['patient'] as Map));
  }
}
