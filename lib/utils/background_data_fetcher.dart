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

  BackgroundDataFetcher._internal();

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
  }

  void stop() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 10), (_) {
      if (_isInForeground) {
        _fetchAndStoreData();
      }
    });
  }

  Future<void> _fetchAndStoreData() async {
    try {
      final response = await http.get(
        Uri.parse('https://crm.medicall.in/api/fetch-visitors'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await storage.write('global_visitor_data', data);
        debugPrint("🔁 Visitor data updated in background.");
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
