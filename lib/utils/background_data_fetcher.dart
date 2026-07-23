import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/scan_vCard.dart';
import 'production_logger.dart';

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
    VCardScanner.uploadUnsyncedLeadsToSupabase();
    _fetchAndStoreHallMaster();
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
        _fetchAndStoreHallMaster();
        VCardScanner.uploadUnsyncedLeadsToSupabase();
      }
    });
  }

  Future<void> _fetchAndStoreData() async {
    try {
      final response = await http
          .get(Uri.parse('https://crm.medicall.in/api/fetch-visitors'))
          .timeout(const Duration(seconds: 180));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('5400-=-=-=->>456  $data');
        if (data != null) {
          await storage.write('global_visitor_data', data);
          ProductionLogger.sync('Visitor data updated in background.');
        }
      } else {
        ProductionLogger.error('Background fetch failed: status code ${response.statusCode}');
      }
    } catch (e) {
      ProductionLogger.error('Error in background visitor fetch', error: e);
    }
  }

  Future<void> _fetchAndStoreHallMaster() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('hall_master')
          .select('id, hall_code, hall_name, display_order, is_active')
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final List<dynamic> responseList = response as List<dynamic>;
      if (responseList.isNotEmpty) {
        await storage.write('hall_master', responseList);
        ProductionLogger.sync('Hall master updated from Supabase: ${responseList.length} halls.');
      }
    } catch (e) {
      ProductionLogger.error('Error fetching hall master from Supabase', error: e);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isInForeground = (state == AppLifecycleState.resumed || state == AppLifecycleState.inactive);
    if (state == AppLifecycleState.resumed) {
      VCardScanner.uploadUnsyncedLeadsToSupabase();
      _fetchAndStoreHallMaster();
    }
  }
}
