import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/visitor_hall_visit.dart';
import '../utils/production_logger.dart';

class VisitorSyncService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Synchronizes a batch of unsynced visitor hall visits to Supabase.
  /// Uses a batch payload insertion. If the batch fails, it falls back to a 
  /// robust record-by-record upload to isolate and handle individual errors or conflicts.
  Future<SyncResult> syncVisits(List<VisitorHallVisit> unsyncedVisits) async {
    if (unsyncedVisits.isEmpty) {
      return SyncResult(updatedVisits: [], hasNetworkErrors: false);
    }

    final List<VisitorHallVisit> updatedVisits = [];
    bool hasNetworkErrors = false;
    const int batchSize = 50;

    for (int i = 0; i < unsyncedVisits.length; i += batchSize) {
      final endIdx = (i + batchSize > unsyncedVisits.length)
          ? unsyncedVisits.length
          : i + batchSize;
      final batch = unsyncedVisits.sublist(i, endIdx);
      final batchPayload = batch.map((v) => v.toSupabasePayload()).toList();

      try {
        ProductionLogger.supabase(
            'Syncing batch payload of size ${batch.length} to Supabase medicall_visitor table.');
        
        await _supabase.from('medicall_visitor').insert(batchPayload);

        final now = DateTime.now();
        for (var visit in batch) {
          updatedVisits.add(visit.copyWith(
            isSynced: true,
            syncedAt: now,
            retryCount: visit.retryCount + 1,
            syncError: null,
          ));
        }
        ProductionLogger.sync('Batch synchronized successfully.');
      } catch (batchError) {
        ProductionLogger.log('WARN',
            'Batch upload failed due to error: $batchError. Initiating one-by-one retry fallback.');

        // If batch fails, we retry each visit individually to ensure that network errors
        // are separated from constraint violations (duplicate uploads).
        for (var visit in batch) {
          try {
            await _supabase
                .from('medicall_visitor')
                .insert(visit.toSupabasePayload());

            final now = DateTime.now();
            updatedVisits.add(visit.copyWith(
              isSynced: true,
              syncedAt: now,
              retryCount: visit.retryCount + 1,
              syncError: null,
            ));
          } on PostgrestException catch (pe) {
            final now = DateTime.now();
            // Handle duplicate key error (Postgres error code 23505) or unique constraint conflicts
            if (pe.code == '23505' ||
                pe.message.contains('duplicate key') ||
                pe.message.contains('violates unique constraint')) {
              ProductionLogger.sync(
                  'Record ${visit.id} has already been uploaded previously. Resolving duplicate conflict by marking as synced.');
              
              updatedVisits.add(visit.copyWith(
                isSynced: true,
                syncedAt: now,
                retryCount: visit.retryCount + 1,
                syncError: null,
              ));
            } else {
              ProductionLogger.error(
                  'Postgres error on single upload for ${visit.id}: ${pe.message}');
              
              updatedVisits.add(visit.copyWith(
                retryCount: visit.retryCount + 1,
                syncError: pe.message,
              ));
              // Treat non-duplicate DB exceptions as potential database or connection errors
              hasNetworkErrors = true;
            }
          } catch (e) {
            ProductionLogger.error(
                'Network or unexpected error on single upload for ${visit.id}: $e');
            
            updatedVisits.add(visit.copyWith(
              retryCount: visit.retryCount + 1,
              syncError: e.toString(),
            ));
            // A network exception causes the sync engine to halt immediately to preserve order
            hasNetworkErrors = true;
            break;
          }
        }

        if (hasNetworkErrors) {
          ProductionLogger.log('WARN',
              'Network connectivity issue detected. Halting further sync iterations.');
          break;
        }
      }
    }

    return SyncResult(
      updatedVisits: updatedVisits,
      hasNetworkErrors: hasNetworkErrors,
    );
  }
}

class SyncResult {
  final List<VisitorHallVisit> updatedVisits;
  final bool hasNetworkErrors;

  SyncResult({required this.updatedVisits, required this.hasNetworkErrors});
}
