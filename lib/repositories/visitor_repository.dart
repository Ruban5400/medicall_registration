import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/visitor_hall_visit.dart';
import '../storage/local_storage_service.dart';
import '../services/visitor_sync_service.dart';
import '../utils/queue_statistics.dart';
import '../utils/app_constants.dart';
import '../utils/production_logger.dart';

class VisitorRepository {
  // Singleton pattern
  static final VisitorRepository _instance = VisitorRepository._internal();
  factory VisitorRepository() => _instance;
  VisitorRepository._internal();

  final LocalStorageService _localService = LocalStorageService();
  final VisitorSyncService _syncService = VisitorSyncService();

  static final ValueNotifier<SyncState> syncState =
      ValueNotifier<SyncState>(SyncState.idle);

  static bool _isSyncing = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// Initializes connectivity listeners to automatically trigger sync when network state returns.
  void initialize() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) async {
      final hasInternet =
          results.any((result) => result != ConnectivityResult.none);
      ProductionLogger.network(
          'Network state changed: hasInternet = $hasInternet');
      if (hasInternet) {
        await triggerSync();
      }
    });
  }

  /// Disposes repository resources.
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Saves a visitor hall visit locally first.
  /// Then triggers an asynchronous background sync if connected.
  Future<void> saveVisit(VisitorHallVisit visit) async {
    final visits = _localService.getVisits();

    // Deduplication check: Same Visitor + Same Hall + Same Date
    final existingIndex = visits.indexWhere((v) =>
        v.visitorMobileNumber == visit.visitorMobileNumber &&
        v.date == visit.date &&
        v.hallNumber == visit.hallNumber);

    if (existingIndex != -1) {
      final existing = visits[existingIndex];
      // If it exists: Update name/email, keep the same local UUID,
      // and reset sync status to unsynced so the updated data is pushed.
      visits[existingIndex] = visit.copyWith(
        id: existing.id,
        isSynced: false,
        syncedAt: null,
        retryCount: existing.retryCount,
        syncError: existing.syncError,
      );
      ProductionLogger.queue(
          'Deduplicated scan for ${visit.visitorMobileNumber} in hall ${visit.hallNumber}. Updated existing local record.');
    } else {
      // If different hall or date: create a new visit record with the generated UUID.
      visits.add(visit);
      ProductionLogger.queue(
          'Saved new visit local record for ${visit.visitorMobileNumber} to queue (UUID: ${visit.id}).');
    }

    await _localService.saveVisits(visits);

    // Trigger sync in background
    triggerSync();
  }

  /// Returns the raw dynamic leads for UI/statistics compatibility.
  List<dynamic> getRawLeads() {
    return _localService.getVisits().map((e) => e.toJson()).toList();
  }

  /// Triggers a non-overlapping synchronization of pending records.
  Future<void> triggerSync() async {
    if (_isSyncing) return;

    final connectivity = await Connectivity().checkConnectivity();
    final hasInternet =
        connectivity.any((result) => result != ConnectivityResult.none);
    if (!hasInternet) {
      ProductionLogger.sync('Offline Mode: Upload skipped.');
      return;
    }

    _isSyncing = true;
    syncState.value = SyncState.syncing;

    try {
      final visits = _localService.getVisits();
      final unsynced = visits.where((v) => !v.isSynced).toList();

      if (unsynced.isEmpty) {
        syncState.value = SyncState.idle;
        ProductionLogger.sync('No pending records in local queue.');
        return;
      }

      final result = await _syncService.syncVisits(unsynced);

      // Merge updated visits back to storage
      final nowList = _localService.getVisits();
      bool modified = false;

      for (var updated in result.updatedVisits) {
        final idx = nowList.indexWhere((v) => v.id == updated.id);
        if (idx != -1) {
          nowList[idx] = updated;
          modified = true;
        }
      }

      if (modified) {
        await _localService.saveVisits(nowList);
        final syncTime = DateFormat('hh:mm a').format(DateTime.now());
        await _localService.writeLastSyncTime(syncTime);
      }

      if (result.hasNetworkErrors) {
        syncState.value = SyncState.failed;
      } else {
        syncState.value = SyncState.synced;
        await cleanupOldSyncedVisits();
      }
    } catch (e) {
      ProductionLogger.error('Fatal error during sync process', error: e);
      syncState.value = SyncState.failed;
    } finally {
      _isSyncing = false;
      // Clear status banner after buffer if we synced successfully
      if (syncState.value == SyncState.synced) {
        Future.delayed(const Duration(seconds: 3), () {
          if (syncState.value == SyncState.synced && !_isSyncing) {
            syncState.value = SyncState.idle;
          }
        });
      }
    }
  }

  /// Cleans up synced records older than the queue retention duration.
  Future<void> cleanupOldSyncedVisits() async {
    try {
      final visits = _localService.getVisits();
      final now = DateTime.now();
      final retentionLimit = now.subtract(AppConstants.queueRetention);

      final List<VisitorHallVisit> updatedList = [];
      bool modified = false;

      for (var visit in visits) {
        if (visit.isSynced) {
          if (visit.checkInTimestamp.isBefore(retentionLimit)) {
            modified = true;
            continue; // Prune
          }
        }
        updatedList.add(visit);
      }

      if (modified) {
        await _localService.saveVisits(updatedList);
        ProductionLogger.queue(
            'Pruned synced records older than ${AppConstants.queueRetention.inHours} hours.');
      }
    } catch (e) {
      ProductionLogger.error('Error cleaning up old synced visits', error: e);
    }
  }
}
