import 'dart:convert';

import 'package:dio/dio.dart';

import '../../utils/logger.dart';
import 'api_endpoints.dart';

class ApiClient {
  ApiClient({required this.logger}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  final Logger logger;
  late final Dio _dio;

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    Options? options,
  }) async {
    logger.d('POST $path');
    final response = await _dio.post(path, data: data, options: options);
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    logger.d('GET $path');
    final response = await _dio.get(
      path,
      queryParameters: queryParameters,
      options: options,
    );
    return _decode(response);
  }

  Future<Response<dynamic>> putRaw(
    String url, {
    required List<int> data,
    Map<String, dynamic>? headers,
  }) async {
    logger.d('PUT $url (raw upload)');
    return _dio.put(
      url,
      data: Stream.fromIterable([data]),
      options: Options(headers: headers),
    );
  }

  Map<String, dynamic> _decode(Response response) {
    if (response.data is Map<String, dynamic>) {
      return response.data as Map<String, dynamic>;
    }
    if (response.data is String) {
      return jsonDecode(response.data as String) as Map<String, dynamic>;
    }
    throw StateError('Unexpected response type: ${response.data.runtimeType}');
  }
}
