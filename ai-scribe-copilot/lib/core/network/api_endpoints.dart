class ApiEndpoints {
  static const String baseUrl = 'https://api.medical-scribe.example';

  static const String startSession = '/v1/upload-session';
  static const String presignedUrl = '/v1/get-presigned-url';
  static const String notifyChunkUploaded = '/v1/notify-chunk-uploaded';
  static const String patients = '/v1/patients';
  static const String addPatient = '/v1/add-patient-ext';
  static String sessionsByPatient(String patientId) =>
      '/v1/fetch-session-by-patient/$patientId';
}
