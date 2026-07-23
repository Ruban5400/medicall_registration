import 'package:flutter/foundation.dart';

class ProductionLogger {
  /// Toggle to enable or disable logs in release builds.
  static bool enabled = kDebugMode;

  /// Standard logger format mapping to categories
  static void log(String category, String message, {Object? error}) {
    if (!enabled) return;
    final timestamp = DateTime.now().toIso8601String();
    final errStr = error != null ? ' | Error: $error' : '';
    debugPrint('[$timestamp] [$category] $message$errStr');
  }

  static void scan(String message) => log('SCAN', message);
  static void queue(String message) => log('QUEUE', message);
  static void sync(String message) => log('SYNC', message);
  static void supabase(String message) => log('SUPABASE', message);
  static void network(String message) => log('NETWORK', message);
  static void error(String message, {Object? error}) => log('ERROR', message, error: error);
  static void performance(String message) => log('PERFORMANCE', message);
}
