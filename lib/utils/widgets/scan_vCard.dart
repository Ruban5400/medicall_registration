import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_beep_plus/flutter_beep_plus.dart';
import '../../models/visitor_hall_visit.dart';
import '../../repositories/visitor_repository.dart';
import '../app_constants.dart';
import '../queue_statistics.dart';
import '../production_logger.dart';


class VCardScanner extends StatefulWidget {
  final String hallNo;

  const VCardScanner(this.hallNo, {super.key});

  /// Global sync state notifier to update the scanning UI in real-time.
  static ValueNotifier<SyncState> get syncState => VisitorRepository.syncState;
  
  /// Uploads ALL unsynced leads from local queue to Supabase.
  static Future<void> uploadUnsyncedLeadsToSupabase() async {
    await VisitorRepository().triggerSync();
  }

  // Alias for backward compatibility
  static Future<void> uploadTodayLeadsToSupabase() async {
    await VisitorRepository().triggerSync();
  }

  @override
  _VCardScannerState createState() => _VCardScannerState();
}

class _VCardScannerState extends State<VCardScanner> with WidgetsBindingObserver {
  bool isScanning = false;
  final _flutterBeepPlusPlugin = FlutterBeepPlus();
  late final MobileScannerController cameraController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    cameraController = MobileScannerController(
      facing: CameraFacing.back,
      detectionSpeed: DetectionSpeed.noDuplicates,
      detectionTimeoutMs: 500,
    );
    _startNetworkListener();
    VCardScanner.syncState.addListener(_onSyncStateChanged);
    VisitorRepository().triggerSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VCardScanner.syncState.removeListener(_onSyncStateChanged);
    _connectivitySubscription?.cancel();
    cameraController.dispose();
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      VisitorRepository().triggerSync();
    }
  }

  Future<void> handleScan(String rawValue) async {
    if (isScanning) return;
    isScanning = true;
    ProductionLogger.scan('Visitor vCard QR scan detected.');

    final contact = Map<String, dynamic>.from(parseCustomVCard(rawValue));

    if (contact.isNotEmpty) {
      final now = DateTime.now();
      
      // Fallback identifier hierarchy for missing mobile numbers to prevent data overwrite
      String mobile = (contact['mobile_number'] ?? '').trim();
      if (mobile.isEmpty) {
        final email = (contact['email'] ?? '').trim();
        if (email.isNotEmpty) {
          mobile = 'EML_${email.hashCode.abs()}';
        } else {
          final regId = (contact['reg_id'] ?? '').trim();
          if (regId.isNotEmpty) {
            mobile = 'REG_${regId.replaceAll(RegExp(r'\s+'), '')}';
          } else {
            mobile = 'GEN_${now.microsecondsSinceEpoch}';
          }
        }
        contact['mobile_number'] = mobile;
        ProductionLogger.queue('Fallback mobile number applied: $mobile');
      }

      final visit = VisitorHallVisit(
        id: VisitorHallVisit.generateUuid(),
        visitorMobileNumber: mobile,
        visitorName: contact['name'] ?? contact['full_name'] ?? '',
        visitorEmail: contact['email'] ?? '',
        hallNumber: widget.hallNo,
        checkInTimestamp: now,
        createdTimestamp: now,
        isSynced: false,
        retryCount: 0,
      );

      await VisitorRepository().saveVisit(visit);

      if (mounted) {
        setState(() {}); // Refresh UI
        showSnackBar('✅ Data saved');
      }

      Future.delayed(AppConstants.scanCooldown, () {
        isScanning = false;
        ProductionLogger.scan('Scanner cooldown finished. Ready for next scan.');
      });
    } else {
      ProductionLogger.error('Parsed vCard is empty or malformed.');
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
      if (mounted) {
        setState(() {
          isConnected = connected;
        });
      }
      ProductionLogger.network('Initial connectivity check: isConnected = $connected');
      if (connected) {
        await VisitorRepository().triggerSync();
      }

      _connectivitySubscription?.cancel();
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) async {
        bool isNowConnected = results.any((result) => result != ConnectivityResult.none);
        ProductionLogger.network('Network connectivity status changed: isConnected = $isNowConnected');
        if (mounted) {
          setState(() {
            isConnected = isNowConnected;
          });
        }
        if (isNowConnected) {
          await VisitorRepository().triggerSync();
        }
      });
    } catch (e) {
      ProductionLogger.error('Connectivity listener error', error: e);
    }
  }


  @override
  Widget build(BuildContext context) {
    // Single-pass calculation of queue statistics from storage
    final leads = VisitorRepository().getRawLeads();
    final stats = QueueStatistics.calculate(leads, VCardScanner.syncState.value);

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

          // Double-layered top dashboard panel (Hall, Network, Live Sync Status, Queue Statistics)
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Layer 1: Main Header (Hall, Connection Status, Scanner state)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.meeting_room_outlined, color: Color(0xFFF1A922), size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "Hall: ${widget.hallNo}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Network Status Indicator
                      Icon(
                        isConnected ? Icons.wifi : Icons.wifi_off,
                        color: isConnected ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isConnected ? "Online" : "Offline",
                        style: TextStyle(
                          color: isConnected ? Colors.green : Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // Scanner ready status badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isScanning ? Colors.orange : const Color(0xFF2E7D32),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isScanning ? "PROCESSING" : "SCAN READY",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Layer 2: Live Sync Status Banner (Changes color and texts dynamically)
                _buildSyncStatusBanner(stats),

                // Layer 3: Queue Statistics Panel (Today's Scans, Pending Uploads, Last Sync Time)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem("Today's Scans", stats.today.toString()),
                      _buildDivider(),
                      _buildStatItem("Pending", stats.pending.toString(), highlight: stats.pending > 0),
                      _buildDivider(),
                      _buildStatItem("Last Sync", stats.lastSync),
                    ],
                  ),
                ),
              ],
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

  /// Builds a dynamic sync banner informing the operator of local and network sync status.
  Widget _buildSyncStatusBanner(QueueStatistics stats) {
    Color bannerColor;
    IconData icon;
    String title;
    String subtitle;

    if (!isConnected) {
      bannerColor = const Color(0xFFD84315); // Deep Orange
      icon = Icons.cloud_off;
      title = "Offline Mode";
      subtitle = "All visitors are being saved locally. Waiting for internet...";
    } else {
      switch (VCardScanner.syncState.value) {
        case SyncState.syncing:
          bannerColor = const Color(0xFF1565C0); // Blue
          icon = Icons.sync;
          title = "Syncing...";
          subtitle = "Syncing pending visitors...";
          break;
        case SyncState.synced:
          bannerColor = const Color(0xFF2E7D32); // Green
          icon = Icons.cloud_done;
          title = "Synced successfully";
          subtitle = "All visitors synchronized";
          break;
        case SyncState.failed:
          bannerColor = const Color(0xFFC62828); // Red
          icon = Icons.warning_amber_rounded;
          title = "Saved locally";
          subtitle = "Will retry automatically";
          break;
        case SyncState.idle:
          if (stats.pending > 0) {
            bannerColor = const Color(0xFFEF6C00); // Orange
            icon = Icons.cloud_queue;
            title = "Saved locally";
            subtitle = "Will retry automatically";
          } else {
            bannerColor = const Color(0xFF2E7D32); // Green
            icon = Icons.cloud_done;
            title = "Synced successfully";
            subtitle = "All visitors synchronized";
          }
          break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.9),
        border: const Border(
          left: BorderSide(color: Colors.white24),
          right: BorderSide(color: Colors.white24),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a vertical divider line between stat entries.
  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white24,
    );
  }

  /// Builds an individual statistic widget.
  Widget _buildStatItem(String label, String value, {bool highlight = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: highlight ? const Color(0xFFFFB300) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
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
