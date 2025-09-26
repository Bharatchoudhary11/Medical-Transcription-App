import 'dart:developer' as developer;

class Logger {
  void d(String message) {
    developer.log(message, name: 'DEBUG');
  }

  void i(String message) {
    developer.log(message, name: 'INFO');
  }

  void w(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(message, name: 'WARN', error: error, stackTrace: stackTrace);
  }

  void e(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(message, name: 'ERROR', error: error, stackTrace: stackTrace);
  }
}
