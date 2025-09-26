import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../utils/logger.dart';

class ConnectivityMonitor {
  ConnectivityMonitor({required this.logger});

  final Logger logger;
  final _connectivity = Connectivity();
  final _controller = StreamController<bool>.broadcast();

  Stream<bool> get onlineStream => _controller.stream;

  Future<void> initialize() async {
    final initialResults = await _connectivity.checkConnectivity();
    _controller.add(_isOnline(initialResults));
    _connectivity.onConnectivityChanged.listen((event) {
      final online = _isOnline(event);
      logger.d('Connectivity changed: $online');
      _controller.add(online);
    });
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) {
      return false;
    }
    return results.any((result) =>
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn);
  }
}
