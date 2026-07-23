import 'package:get_storage/get_storage.dart';
import 'package:intl/intl.dart';

enum SyncState { idle, syncing, synced, failed }

class QueueStatistics {
  final int pending;
  final int synced;
  final int today;
  final int failed;
  final String lastSync;

  QueueStatistics({
    required this.pending,
    required this.synced,
    required this.today,
    required this.failed,
    required this.lastSync,
  });

  /// Calculates statistics from the raw list of leads in a single pass.
  factory QueueStatistics.calculate(List<dynamic> leads, SyncState currentSyncState) {
    int pending = 0;
    int synced = 0;
    int today = 0;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    for (var lead in leads) {
      if (lead is Map) {
        final isSynced = lead['is_synced'] == true;
        if (isSynced) {
          synced++;
        } else {
          pending++;
        }

        if (lead['date'] == todayStr) {
          today++;
        }
      }
    }

    // Retrieve last sync timestamp from GetStorage
    final lastSyncTimeStr = GetStorage().read<String>('last_sync_time') ?? 'Never';

    // If sync state is currently failed, we report the unsynced queue count as failed
    final failedCount = (currentSyncState == SyncState.failed) ? pending : 0;

    return QueueStatistics(
      pending: pending,
      synced: synced,
      today: today,
      failed: failedCount,
      lastSync: lastSyncTimeStr,
    );
  }
}
