import 'package:dio/dio.dart';

/// No-op fallback used for platforms that do not expose a dart:io [HttpClient].
void configureHttpClientAdapter(
  Dio dio, {
  Duration? connectionTimeout,
}) {}
