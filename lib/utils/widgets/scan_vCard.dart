import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_beep_plus/flutter_beep_plus.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VCardScanner extends StatefulWidget {
  final String hallNo;

  const VCardScanner(this.hallNo, {super.key});

  @override
  _VCardScannerState createState() => _VCardScannerState();
}

class _VCardScannerState extends State<VCardScanner> {
  final box = GetStorage();
  bool isScanning = false;
  final _flutterBeepPlusPlugin = FlutterBeepPlus();
  late final MobileScannerController cameraController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    box.writeIfNull('leads', []);
    cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 500,
    );
    _startNetworkListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    cameraController.dispose();
    super.dispose();
  }

  Future<void> handleScan(String rawValue) async {
    if (isScanning) return;
    isScanning = true;

    final contact = Map<String, dynamic>.from(parseCustomVCard(rawValue));

    if (contact.isNotEmpty) {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(now);

      contact['hall_no'] = widget.hallNo;
      contact['date'] = formattedDate;
      contact['is_synced'] = false;

      final List<dynamic> currentLeads = box.read('leads') ?? [];
      currentLeads.add(contact);
      await box.write('leads', currentLeads);

      if (mounted) {
        setState(() {}); // Refresh UI
        showSnackBar('✅ Data saved');
      }

      Future.delayed(const Duration(seconds: 2), () {
        isScanning = false;
      });
    } else {
      if (mounted) {
        showSnackBar('❌ Invalid or incomplete vCard');
      }
      isScanning = false;
    }
  }

  void showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  bool isConnected = false;

  void _startNetworkListener() async {
    try {
      final initialResults = await Connectivity().checkConnectivity();
      bool connected = initialResults.any((result) => result != ConnectivityResult.none);
      if (connected) {
        await uploadTodayLeadsToSupabase();
      }

      _connectivitySubscription?.cancel();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
        bool isNowConnected = results.any((result) => result != ConnectivityResult.none);
        if (isNowConnected) {
          await uploadTodayLeadsToSupabase();
        }
      });
    } catch (e) {
      debugPrint('Connectivity listener error: $e');
    }
  }

  Future<void> uploadTodayLeadsToSupabase() async {
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final List<dynamic> scannedLeadsRaw = box.read('leads') ?? [];

    final List<Map<String, dynamic>> scannedLeads =
        scannedLeadsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

    final unsyncedTodayLeads = scannedLeads.where((lead) {
      final leadDate = lead['date'];
      final isSynced = lead['is_synced'] == true;
      return leadDate == todayStr && !isSynced;
    }).toList();

    if (unsyncedTodayLeads.isEmpty) {
      return;
    }

    final filteredLeads = unsyncedTodayLeads
        .map((lead) => {
              'name': lead['name'],
              'email': lead['email'],
              'mobile_number': lead['mobile_number'],
              'hall_no': lead['hall_no'],
              'date': lead['date'],
            })
        .toList();

    final supabase = Supabase.instance.client;

    try {
      await supabase.from('medicall_visitor').insert(filteredLeads);

      // Upon successful insert, mark uploaded entries as is_synced = true
      final updatedLeadsRaw = scannedLeadsRaw.map((e) {
        final map = Map<String, dynamic>.from(e);
        if (map['date'] == todayStr && map['is_synced'] != true) {
          map['is_synced'] = true;
        }
        return map;
      }).toList();

      await box.write('leads', updatedLeadsRaw);
    } catch (e) {
      debugPrint('❌ Error uploading leads: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Scan vCard',
          style: TextStyle(
            color: Colors.indigo,
            fontSize: 25,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.indigo),
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (barcodeCapture) {
          final barcode = barcodeCapture.barcodes.first;
          final raw = barcode.rawValue;
          _flutterBeepPlusPlugin
              .playSysSound(AndroidSoundID.TONE_CDMA_ABBR_ALERT);
          if (barcode.format == BarcodeFormat.qrCode &&
              raw != null &&
              raw.startsWith("BEGIN:VCARD")) {
            handleScan(raw);
          }
        },
      ),
    );
  }

  Map<String, String> parseCustomVCard(String vCard) {
    final lines = vCard.split('\n');
    final data = <String, String>{};

    for (final line in lines) {
      if (line.startsWith('N:')) {
        data['name'] = line.replaceFirst('N:', '').trim();
      } else if (line.startsWith('FN:')) {
        data['full_name'] = line.replaceFirst('FN:', '').trim();
      } else if (line.startsWith('EMAIL:')) {
        data['email'] = line.replaceFirst('EMAIL:', '').trim();
      } else if (line.startsWith('ORG:')) {
        data['organization'] = line.replaceFirst('ORG:', '').trim();
      } else if (line.startsWith('TITLE:')) {
        data['designation'] = line.replaceFirst('TITLE:', '').trim();
      } else if (line.startsWith('TEL;TYPE=CELL:')) {
        data['mobile_number'] = line.replaceFirst('TEL;TYPE=CELL:', '').trim();
      } else if (line.startsWith('ADR:')) {
        data['address'] = line.replaceFirst('ADR:', '').trim();
      } else if (line.startsWith('REG_ID:')) {
        data['reg_id'] = line.replaceFirst('REG_ID:', '').trim();
      }
    }

    return data;
  }
}
