import 'package:dio/dio.dart';
import 'package:dio/io.dart';

void configureHttpClientAdapter(
  Dio dio, {
  Duration? connectionTimeout,
}) {
  final adapter = dio.httpClientAdapter;
  if (adapter is IOHttpClientAdapter) {
    final previous = adapter.onHttpClientCreate;
    adapter.onHttpClientCreate = (client) {
      if (connectionTimeout != null) {
        client.connectionTimeout = connectionTimeout;
      }
      return previous?.call(client) ?? client;
    };
  }
}
