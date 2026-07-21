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

  static bool _isSyncing = false;

  /// Uploads ALL unsynced leads from GetStorage to Supabase regardless of scan date.
  /// Uses a batching mechanism (50 leads per batch) and a static concurrency guard.
  static Future<void> uploadUnsyncedLeadsToSupabase() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final box = GetStorage();
      final List<dynamic> scannedLeadsRaw = box.read('leads') ?? [];
      if (scannedLeadsRaw.isEmpty) return;

      final List<Map<String, dynamic>> scannedLeads =
          scannedLeadsRaw.map((e) => Map<String, dynamic>.from(e)).toList();

      final unsyncedIndices = <int>[];
      for (int i = 0; i < scannedLeads.length; i++) {
        if (scannedLeads[i]['is_synced'] != true) {
          unsyncedIndices.add(i);
        }
      }

      if (unsyncedIndices.isEmpty) return;

      final supabase = Supabase.instance.client;
      const int batchSize = 50;

      for (int i = 0; i < unsyncedIndices.length; i += batchSize) {
        final endIdx = (i + batchSize > unsyncedIndices.length)
            ? unsyncedIndices.length
            : i + batchSize;
        final batchIndices = unsyncedIndices.sublist(i, endIdx);

        final batchPayload = batchIndices.map((idx) {
          final lead = scannedLeads[idx];
          return {
            'name': lead['name'] ?? '',
            'email': lead['email'] ?? '',
            'mobile_number': lead['mobile_number'] ?? '',
            'hall_no': lead['hall_no'] ?? '',
            'date': lead['date'] ?? '',
          };
        }).toList();

        try {
          await supabase.from('medicall_visitor').upsert(
            batchPayload,
            onConflict: 'mobile_number,date',
          );

          // Update GetStorage immediately after this batch succeeds
          final currentRaw = box.read('leads') ?? [];
          final currentList =
              currentRaw.map((e) => Map<String, dynamic>.from(e)).toList();

          for (final idx in batchIndices) {
            if (idx < currentList.length) {
              currentList[idx]['is_synced'] = true;
            }
          }
          await box.write('leads', currentList);
          debugPrint('✅ Synced batch of ${batchPayload.length} leads to Supabase.');
        } catch (e) {
          debugPrint('❌ Supabase batch upload error: $e');
          break; // Stop further batch attempts if network fails
        }
      }
    } catch (e) {
      debugPrint('❌ Sync engine error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  // Alias for backward compatibility
  static Future<void> uploadTodayLeadsToSupabase() async {
    await uploadUnsyncedLeadsToSupabase();
  }

  @override
  _VCardScannerState createState() => _VCardScannerState();
}

class _VCardScannerState extends State<VCardScanner> with WidgetsBindingObserver {
  final box = GetStorage();
  bool isScanning = false;
  final _flutterBeepPlusPlugin = FlutterBeepPlus();
  late final MobileScannerController cameraController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    box.writeIfNull('leads', []);
    cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 500,
    );
    _startNetworkListener();
    VCardScanner.uploadUnsyncedLeadsToSupabase();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      VCardScanner.uploadUnsyncedLeadsToSupabase();
    }
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

      // Trigger background upload attempt immediately after scan
      VCardScanner.uploadUnsyncedLeadsToSupabase();

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
        await VCardScanner.uploadUnsyncedLeadsToSupabase();
      }

      _connectivitySubscription?.cancel();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
        bool isNowConnected = results.any((result) => result != ConnectivityResult.none);
        if (isNowConnected) {
          await VCardScanner.uploadUnsyncedLeadsToSupabase();
        }
      });
    } catch (e) {
      debugPrint('Connectivity listener error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'vCard Check-In Scanner',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF1A922),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          MobileScanner(
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

          // Top Info Banner Overlay
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Row(
                children: [
                  const Icon(Icons.meeting_room_outlined, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Hall: ${widget.hallNo}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "SCAN READY",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Guidance Overlay
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: const Text(
                "Place the QR Code inside the frame\nScanning automatically...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
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
