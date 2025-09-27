import 'dart:convert';

import 'package:dio/dio.dart';

import '../../utils/logger.dart';
import '../config/app_config.dart';
import 'http_client_adapter_stub.dart'
    if (dart.library.io) 'http_client_adapter_io.dart' as http_client;

class ApiClient {
  ApiClient({required this.logger}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    http_client.configureHttpClientAdapter(
      _dio,
      connectionTimeout: const Duration(seconds: 30),
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

  Future<Response<dynamic>> uploadRaw(
    String url,
    List<int> data, {
    Map<String, dynamic>? headers,
    String method = 'PUT',
  }) async {
    final upperMethod = method.toUpperCase();
    logger.d('$upperMethod $url (raw upload)');
    return _dio.request(
      url,
      data: Stream.fromIterable([data]),
      options: Options(
        method: upperMethod,
        headers: headers,
      ),
    );
  }

  Future<Response<dynamic>> send(
    String method,
    String url, {
    dynamic data,
    Map<String, dynamic>? headers,
  }) async {
    final upperMethod = method.toUpperCase();
    logger.d('$upperMethod $url');
    return _dio.request(
      url,
      data: data,
      options: Options(
        method: upperMethod,
        headers: headers,
      ),
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
