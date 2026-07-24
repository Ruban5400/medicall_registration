import 'dart:math';

class VisitorHallVisit {
  final String id;
  final String visitorMobileNumber;
  final String visitorName;
  final String visitorEmail;
  final String hallNumber;
  final DateTime checkInTimestamp;
  final DateTime createdTimestamp;
  final bool isSynced;
  final DateTime? syncedAt;
  final int retryCount;
  final String? syncError;

  VisitorHallVisit({
    required this.id,
    required this.visitorMobileNumber,
    required this.visitorName,
    required this.visitorEmail,
    required this.hallNumber,
    required this.checkInTimestamp,
    required this.createdTimestamp,
    required this.isSynced,
    this.syncedAt,
    required this.retryCount,
    this.syncError,
  });

  String get date => checkInTimestamp.toIso8601String().split('T')[0];

  Map<String, dynamic> toJson() => {
        'id': id,
        'mobile_number': visitorMobileNumber,
        'name': visitorName,
        'email': visitorEmail,
        'hall_no': hallNumber,
        'check_in_timestamp': checkInTimestamp.toIso8601String(),
        'created_timestamp': createdTimestamp.toIso8601String(),
        'is_synced': isSynced,
        'synced_at': syncedAt?.toIso8601String(),
        'retry_count': retryCount,
        'sync_error': syncError,
        'date': date,
      };

  factory VisitorHallVisit.fromJson(Map<String, dynamic> json) =>
      VisitorHallVisit(
        id: (json['id'] != null && json['id'].toString().isNotEmpty)
            ? json['id']
            : generateUuid(),
        visitorMobileNumber: json['mobile_number'] ?? '',
        visitorName: json['name'] ?? '',
        visitorEmail: json['email'] ?? '',
        hallNumber: json['hall_no'] ?? '',
        checkInTimestamp: json['check_in_timestamp'] != null
            ? DateTime.parse(json['check_in_timestamp'])
            : (json['scanned_at'] != null
                ? DateTime.parse(json['scanned_at'].toString())
                : (json['date'] != null
                    ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
                    : DateTime.now())),
        createdTimestamp: json['created_timestamp'] != null
            ? DateTime.parse(json['created_timestamp'])
            : (json['scanned_at'] != null
                ? DateTime.parse(json['scanned_at'].toString())
                : DateTime.now()),
        isSynced: json['is_synced'] ?? false,
        syncedAt: json['synced_at'] != null
            ? DateTime.parse(json['synced_at'])
            : null,
        retryCount: json['retry_count'] ?? 0,
        syncError: json['sync_error'],
      );

  VisitorHallVisit copyWith({
    String? id,
    String? visitorMobileNumber,
    String? visitorName,
    String? visitorEmail,
    String? hallNumber,
    DateTime? checkInTimestamp,
    DateTime? createdTimestamp,
    bool? isSynced,
    DateTime? syncedAt,
    int? retryCount,
    String? syncError,
  }) {
    return VisitorHallVisit(
      id: id ?? this.id,
      visitorMobileNumber: visitorMobileNumber ?? this.visitorMobileNumber,
      visitorName: visitorName ?? this.visitorName,
      visitorEmail: visitorEmail ?? this.visitorEmail,
      hallNumber: hallNumber ?? this.hallNumber,
      checkInTimestamp: checkInTimestamp ?? this.checkInTimestamp,
      createdTimestamp: createdTimestamp ?? this.createdTimestamp,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      retryCount: retryCount ?? this.retryCount,
      syncError: syncError ?? this.syncError,
    );
  }

  /// Maps the visit domain entity to the schema fields of medicall_visitor Supabase table.
  Map<String, dynamic> toSupabasePayload() => {
        'id': id,
        'name': visitorName,
        'email': visitorEmail,
        'mobile_number': visitorMobileNumber,
        'hall_no': hallNumber,
        'date': checkInTimestamp.toIso8601String().split('T')[0], // yyyy-MM-dd
      };

  /// Generates a secure, cryptographically random RFC 4122 v4 UUID.
  static String generateUuid() {
    final random = Random.secure();
    final hex = List.generate(16, (i) => random.nextInt(256));

    // Set version to 4 (0100xxxx)
    hex[6] = (hex[6] & 0x0f) | 0x40;
    // Set variant to RFC 4122 (10xxxxxx)
    hex[8] = (hex[8] & 0x3f) | 0x80;

    String toHex(int val) => val.toRadixString(16).padLeft(2, '0');

    return '${toHex(hex[0])}${toHex(hex[1])}${toHex(hex[2])}${toHex(hex[3])}-'
        '${toHex(hex[4])}${toHex(hex[5])}-'
        '${toHex(hex[6])}${toHex(hex[7])}-'
        '${toHex(hex[8])}${toHex(hex[9])}-'
        '${toHex(hex[10])}${toHex(hex[11])}${toHex(hex[12])}${toHex(hex[13])}${toHex(hex[14])}${toHex(hex[15])}';
  }
}
