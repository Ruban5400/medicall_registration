import 'package:get_storage/get_storage.dart';
import '../models/visitor_hall_visit.dart';

class LocalStorageService {
  final GetStorage _box = GetStorage();
  static const String _leadsKey = 'leads';

  /// Reads and parses all local visitor hall visits from storage.
  List<VisitorHallVisit> getVisits() {
    final List<dynamic> raw = _box.read(_leadsKey) ?? [];
    return raw
        .map((e) => VisitorHallVisit.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Writes all local visitor hall visits back to storage.
  Future<void> saveVisits(List<VisitorHallVisit> visits) async {
    final raw = visits.map((e) => e.toJson()).toList();
    await _box.write(_leadsKey, raw);
  }

  /// Writes the last successful synchronization time representation (hh:mm a).
  Future<void> writeLastSyncTime(String formattedTime) async {
    await _box.write('last_sync_time', formattedTime);
  }
}
