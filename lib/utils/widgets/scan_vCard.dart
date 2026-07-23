import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_beep_plus/flutter_beep_plus.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../app_constants.dart';
import '../queue_statistics.dart';
import '../production_logger.dart';


class VCardScanner extends StatefulWidget {
  final String hallNo;

  const VCardScanner(this.hallNo, {super.key});

  static bool _isSyncing = false;
  
  /// Global sync state notifier to update the scanning UI in real-time.
  static final ValueNotifier<SyncState> syncState = ValueNotifier<SyncState>(SyncState.idle);

  /// Uploads ALL unsynced leads from GetStorage to Supabase regardless of scan date.
  /// Uses a batching mechanism (50 leads per batch) and a static concurrency guard.
  static Future<void> uploadUnsyncedLeadsToSupabase() async {
    if (_isSyncing) return;
    _isSyncing = true;
    syncState.value = SyncState.syncing;
    ProductionLogger.sync('Starting upload of unsynced visitor leads...');

    try {
      final box = GetStorage();
      final List<dynamic> scannedLeadsRaw = box.read('leads') ?? [];
      if (scannedLeadsRaw.isEmpty) {
        syncState.value = SyncState.idle;
        ProductionLogger.sync('No visitor records found in local queue.');
        return;
      }

      // Optimized single-pass index extraction to avoid mapping 10k items up front
      final unsyncedIndices = <int>[];
      for (int i = 0; i < scannedLeadsRaw.length; i++) {
        final lead = scannedLeadsRaw[i];
        if (lead is Map && lead['is_synced'] != true) {
          unsyncedIndices.add(i);
        }
      }

      if (unsyncedIndices.isEmpty) {
        syncState.value = SyncState.idle;
        ProductionLogger.sync('All local visitor records are already synchronized.');
        return;
      }

      final supabase = Supabase.instance.client;
      const int batchSize = 50;
      ProductionLogger.sync('Found ${unsyncedIndices.length} unsynced leads. Processing in batches of $batchSize.');

      for (int i = 0; i < unsyncedIndices.length; i += batchSize) {
        final endIdx = (i + batchSize > unsyncedIndices.length)
            ? unsyncedIndices.length
            : i + batchSize;
        final batchIndices = unsyncedIndices.sublist(i, endIdx);

        // Optimized payload mapping from raw data source
        final batchPayload = batchIndices.map((idx) {
          final lead = scannedLeadsRaw[idx] as Map;
          return {
            'name': lead['name'] ?? '',
            'email': lead['email'] ?? '',
            'mobile_number': lead['mobile_number'] ?? '',
            'hall_no': lead['hall_no'] ?? '',
            'date': lead['date'] ?? '',
          };
        }).toList();

        try {
          ProductionLogger.supabase('Upserting batch payload to medicall_visitor table (size: ${batchPayload.length}).');
          await supabase.from('medicall_visitor').upsert(
            batchPayload,
            onConflict: 'mobile_number,date',
          );

          // Update GetStorage immediately after this batch succeeds, pull fresh data to avoid races
          final currentRaw = box.read('leads') ?? [];
          final currentList =
              currentRaw.map((e) => Map<String, dynamic>.from(e)).toList();

          for (final idx in batchIndices) {
            if (idx < currentList.length) {
              currentList[idx]['is_synced'] = true;
            }
          }
          await box.write('leads', currentList);
          
          // Persist the last successful sync time formatted as hh:mm a
          final syncTime = DateFormat('hh:mm a').format(DateTime.now());
          await box.write('last_sync_time', syncTime);

          ProductionLogger.sync('Successfully synchronized batch of ${batchPayload.length} leads.');
        } catch (e) {
          ProductionLogger.error('Supabase batch upload network or database error', error: e);
          syncState.value = SyncState.failed;
          break; // Stop further batch attempts if network fails
        }
      }

      // If we finished all batches without breaking, state is synced
      if (syncState.value == SyncState.syncing) {
        syncState.value = SyncState.synced;
        // Trigger optimized queue cleanup
        await _cleanupSyncedQueue();
      }
    } catch (e) {
      ProductionLogger.error('Sync engine fatal error', error: e);
      syncState.value = SyncState.failed;
    } finally {
      _isSyncing = false;
      // Revert sync state back to idle after a 3-second display buffer
      if (syncState.value == SyncState.synced) {
        Future.delayed(const Duration(seconds: 3), () {
          if (syncState.value == SyncState.synced && !_isSyncing) {
            syncState.value = SyncState.idle;
          }
        });
      }
    }
  }

  /// Prunes successfully synced visitor records older than configured retention period (24 hours).
  /// Designed to perform efficiently in a single pass without locking resources.
  static Future<void> _cleanupSyncedQueue() async {
    try {
      final box = GetStorage();
      final List<dynamic> currentRaw = box.read('leads') ?? [];
      if (currentRaw.isEmpty) return;

      final now = DateTime.now();
      final retentionLimit = now.subtract(AppConstants.queueRetention);

      final List<dynamic> updatedList = [];
      bool modified = false;

      for (var lead in currentRaw) {
        if (lead is Map) {
          if (lead['is_synced'] == true) {
            DateTime? leadTime;
            if (lead['scanned_at'] != null) {
              leadTime = DateTime.tryParse(lead['scanned_at'].toString());
            }
            leadTime ??= DateTime.tryParse(lead['date']?.toString() ?? '');

            if (leadTime != null && leadTime.isBefore(retentionLimit)) {
              modified = true;
              continue; // Exclude/prune from memory
            }
          }
        }
        updatedList.add(lead);
      }

      if (modified) {
        await box.write('leads', updatedList);
        ProductionLogger.queue('Pruned synced records older than ${AppConstants.queueRetention.inHours} hours.');
      }
    } catch (e) {
      ProductionLogger.error('Queue cleanup background error', error: e);
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
    VCardScanner.syncState.addListener(_onSyncStateChanged);
    VCardScanner.uploadUnsyncedLeadsToSupabase();
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
      VCardScanner.uploadUnsyncedLeadsToSupabase();
    }
  }

  Future<void> handleScan(String rawValue) async {
    if (isScanning) return;
    isScanning = true;
    ProductionLogger.scan('Visitor vCard QR scan detected.');

    final contact = Map<String, dynamic>.from(parseCustomVCard(rawValue));

    if (contact.isNotEmpty) {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd').format(now);
      
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

      contact['hall_no'] = widget.hallNo;
      contact['date'] = formattedDate;
      contact['scanned_at'] = now.toIso8601String(); // Add high-res local scan timestamp
      contact['is_synced'] = false;

      final List<dynamic> currentLeads = box.read('leads') ?? [];
      
      // Dynamic Deduplication: update the matching local record in-place
      final existingIndex = currentLeads.indexWhere((lead) => 
          lead is Map && lead['mobile_number'] == mobile && lead['date'] == formattedDate);

      if (existingIndex != -1) {
        final existingLead = Map<String, dynamic>.from(currentLeads[existingIndex]);
        existingLead['is_synced'] = false;
        existingLead['scanned_at'] = now.toIso8601String();
        existingLead['name'] = contact['name'] ?? existingLead['name'] ?? '';
        existingLead['email'] = contact['email'] ?? existingLead['email'] ?? '';
        existingLead['hall_no'] = widget.hallNo;
        currentLeads[existingIndex] = existingLead;
        ProductionLogger.queue('Duplicate scan for $mobile on $formattedDate. Updated existing local record in-place.');
      } else {
        currentLeads.add(contact);
        ProductionLogger.queue('Saved new scan to local queue for $mobile.');
      }

      await box.write('leads', currentLeads);

      if (mounted) {
        setState(() {}); // Refresh UI
        showSnackBar('✅ Data saved');
      }

      // Trigger background upload attempt immediately after scan
      VCardScanner.uploadUnsyncedLeadsToSupabase();

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
        await VCardScanner.uploadUnsyncedLeadsToSupabase();
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
          await VCardScanner.uploadUnsyncedLeadsToSupabase();
        }
      });
    } catch (e) {
      ProductionLogger.error('Connectivity listener error', error: e);
    }
  }


  @override
  Widget build(BuildContext context) {
    // Single-pass calculation of queue statistics from storage
    final leads = box.read('leads') ?? [];
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
