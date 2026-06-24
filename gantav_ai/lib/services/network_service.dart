import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Network connectivity monitoring service
class NetworkService {
  static final Connectivity _connectivity = Connectivity();
  static bool _isOnline = true;

  /// Whether the device is currently online
  static bool get isOnline => _isOnline;

  /// Stream of connectivity changes
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map((results) {
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      return _isOnline;
    });
  }

  /// Check current connectivity
  static Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _isOnline = results.any((r) => r != ConnectivityResult.none);
      return _isOnline;
    } catch (e) {
      debugPrint('Connectivity check failed: $e');
      return true; // Assume online if check fails
    }
  }
}
