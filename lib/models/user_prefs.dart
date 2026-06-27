/// User-configurable settings, persisted via shared_preferences.
class UserPrefs {
  /// "I'm sensitive" toggle (asthma / heart-lung condition / elderly / kids).
  final bool sensitive;

  /// AQI alert threshold. Defaults derive from [sensitive] (50 vs 100) but
  /// the user can override.
  final int alertThreshold;

  /// Daily background alert checks on/off.
  final bool alertsEnabled;

  /// Daily morning + evening summary reports on/off.
  final bool reportsEnabled;

  /// Reduce-motion: fall back to clean static visuals.
  final bool reduceMotion;

  const UserPrefs({
    this.sensitive = false,
    this.alertThreshold = 100,
    this.alertsEnabled = true,
    this.reportsEnabled = true,
    this.reduceMotion = false,
  });

  /// The default threshold implied by the sensitivity toggle.
  static int defaultThresholdFor(bool sensitive) => sensitive ? 50 : 100;

  UserPrefs copyWith({
    bool? sensitive,
    int? alertThreshold,
    bool? alertsEnabled,
    bool? reportsEnabled,
    bool? reduceMotion,
  }) =>
      UserPrefs(
        sensitive: sensitive ?? this.sensitive,
        alertThreshold: alertThreshold ?? this.alertThreshold,
        alertsEnabled: alertsEnabled ?? this.alertsEnabled,
        reportsEnabled: reportsEnabled ?? this.reportsEnabled,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );
}
