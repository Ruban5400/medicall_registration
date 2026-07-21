import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;

class BackgroundDataFetcher with WidgetsBindingObserver {
  static final BackgroundDataFetcher _instance = BackgroundDataFetcher._internal();
  factory BackgroundDataFetcher() => _instance;

  final GetStorage storage = GetStorage();
  Timer? _timer;
  bool _isInForeground = true;
  bool _isStarted = false;

  BackgroundDataFetcher._internal();

  void start() {
    if (_isStarted) return;
    _isStarted = true;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _isStarted = false;
  }

  void _startTimer() {
    if (_timer != null && _timer!.isActive) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (_isInForeground) {
        _fetchAndStoreData();
      }
    });
  }

  Future<void> _fetchAndStoreData() async {
    try {
      final response = await http
          .get(Uri.parse('https://crm.medicall.in/api/fetch-visitors'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null) {
          await storage.write('global_visitor_data', data);
          debugPrint("🔁 Visitor data updated in background.");
        }
      } else {
        debugPrint("❌ Background fetch failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error in background fetch: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInForeground = (state == AppLifecycleState.resumed || state == AppLifecycleState.inactive);
  }
}
