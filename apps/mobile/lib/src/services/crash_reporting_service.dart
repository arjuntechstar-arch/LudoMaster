import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CrashLogEntry {
  final String timestamp;
  final String message;
  final String stackTrace;
  final String context;

  CrashLogEntry({
    required this.timestamp,
    required this.message,
    required this.stackTrace,
    required this.context,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'message': message,
        'stackTrace': stackTrace,
        'context': context,
      };

  factory CrashLogEntry.fromJson(Map<String, dynamic> json) => CrashLogEntry(
        timestamp: json['timestamp'] as String? ?? '',
        message: json['message'] as String? ?? '',
        stackTrace: json['stackTrace'] as String? ?? '',
        context: json['context'] as String? ?? '',
      );
}

/// In-app crash reporting, unhandled error logging, and diagnostic telemetry.
class CrashReportingService {
  static const String _keyCrashLogs = 'ludomaster_diagnostic_crash_logs';
  static final List<CrashLogEntry> _recentCrashes = [];
  static bool _initialized = false;

  static List<CrashLogEntry> get inMemoryLogs => List.unmodifiable(_recentCrashes);

  /// Initializes Flutter unhandled framework errors and async platform error interceptors.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    // 1. Flutter framework error handler
    FlutterError.onError = (FlutterErrorDetails details) {
      logError(
        details.exceptionAsString(),
        stackTrace: details.stack,
        context: 'Flutter Framework Error (${details.context})',
      );
      FlutterError.presentError(details);
    };

    // 2. Uncaught asynchronous errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      logError(
        error.toString(),
        stackTrace: stack,
        context: 'PlatformDispatcher Uncaught Async Error',
      );
      return true; // handled
    };
  }

  /// Manually log an error or warning
  static void logError(
    String message, {
    StackTrace? stackTrace,
    String context = 'Application Code',
  }) {
    final entry = CrashLogEntry(
      timestamp: DateTime.now().toUtc().toIso8601String(),
      message: message,
      stackTrace: stackTrace?.toString() ?? StackTrace.current.toString(),
      context: context,
    );

    _recentCrashes.insert(0, entry);
    if (_recentCrashes.length > 50) {
      _recentCrashes.removeLast();
    }

    _persistCrash(entry);
  }

  static Future<void> _persistCrash(CrashLogEntry entry) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getStringList(_keyCrashLogs) ?? [];
      existingJson.insert(0, jsonEncode(entry.toJson()));
      if (existingJson.length > 20) {
        existingJson.removeRange(20, existingJson.length);
      }
      await prefs.setStringList(_keyCrashLogs, existingJson);
    } catch (_) {}
  }

  /// Retrieves persisted error logs from local storage.
  static Future<List<CrashLogEntry>> getPersistedLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyCrashLogs) ?? [];
      return rawList
          .map((item) => CrashLogEntry.fromJson(jsonDecode(item) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Clears stored crash diagnostics.
  static Future<void> clearLogs() async {
    _recentCrashes.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyCrashLogs);
    } catch (_) {}
  }
}
