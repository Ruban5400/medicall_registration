class AppConstants {
  /// Cooldown between scans to prevent accidental double scans.
  static const Duration scanCooldown = Duration(milliseconds: 1200);

  /// Queue retention duration for synced leads before they are pruned.
  static const Duration queueRetention = Duration(hours: 24);
}
