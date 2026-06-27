import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/air_quality.dart';
import '../models/forecast.dart';
import '../models/place.dart';
import '../models/user_prefs.dart';

/// Thin wrapper over shared_preferences for settings, last location and the
/// cached reading. All keys live here so background isolate + UI agree.
class StorageService {
  static const _kSensitive = 'pref_sensitive';
  static const _kThreshold = 'pref_threshold';
  static const _kThresholdSetByUser = 'pref_threshold_user_set';
  static const _kAlertsEnabled = 'pref_alerts_enabled';
  static const _kReportsEnabled = 'pref_reports_enabled';
  static const _kReduceMotion = 'pref_reduce_motion';

  static const _kLastPlace = 'last_place';
  static const _kSavedPlaces = 'saved_places';
  static const _kCachedReading = 'cached_reading';
  static const _kCachedPlaceLabel = 'cached_place_label';
  static const _kCachedHourly = 'cached_hourly';

  static const _kLastNotifiedAqi = 'last_notified_aqi';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  // ----- User prefs -----

  Future<UserPrefs> loadPrefs() async {
    final p = await _prefs;
    return UserPrefs(
      sensitive: p.getBool(_kSensitive) ?? false,
      alertThreshold: p.getInt(_kThreshold) ?? 100,
      alertsEnabled: p.getBool(_kAlertsEnabled) ?? true,
      reportsEnabled: p.getBool(_kReportsEnabled) ?? true,
      reduceMotion: p.getBool(_kReduceMotion) ?? false,
    );
  }

  Future<void> savePrefs(UserPrefs prefs) async {
    final p = await _prefs;
    await p.setBool(_kSensitive, prefs.sensitive);
    await p.setInt(_kThreshold, prefs.alertThreshold);
    await p.setBool(_kAlertsEnabled, prefs.alertsEnabled);
    await p.setBool(_kReportsEnabled, prefs.reportsEnabled);
    await p.setBool(_kReduceMotion, prefs.reduceMotion);
  }

  /// Whether the user has manually edited the threshold (so we stop
  /// auto-syncing it to the sensitivity default).
  Future<bool> thresholdSetByUser() async {
    final p = await _prefs;
    return p.getBool(_kThresholdSetByUser) ?? false;
  }

  Future<void> setThresholdSetByUser(bool value) async {
    final p = await _prefs;
    await p.setBool(_kThresholdSetByUser, value);
  }

  // ----- Last location -----

  Future<Place?> loadLastPlace() async {
    final p = await _prefs;
    final raw = p.getString(_kLastPlace);
    if (raw == null) return null;
    try {
      return Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLastPlace(Place place) async {
    final p = await _prefs;
    await p.setString(_kLastPlace, jsonEncode(place.toJson()));
  }

  // ----- Saved places (multiple locations) -----

  Future<List<Place>> loadSavedPlaces() async {
    final p = await _prefs;
    final raw = p.getString(_kSavedPlaces);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(Place.fromJson)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeSavedPlaces(List<Place> places) async {
    final p = await _prefs;
    await p.setString(
        _kSavedPlaces, jsonEncode(places.map((e) => e.toJson()).toList()));
  }

  /// Two places are "the same" if their coordinates match to ~3 decimals.
  static bool _samePlace(Place a, Place b) =>
      (a.latitude - b.latitude).abs() < 0.005 &&
      (a.longitude - b.longitude).abs() < 0.005;

  /// Add a place if not already saved; returns the updated list.
  Future<List<Place>> addSavedPlace(Place place) async {
    final places = await loadSavedPlaces();
    if (places.any((e) => _samePlace(e, place))) return places;
    places.add(place);
    await _writeSavedPlaces(places);
    return places;
  }

  Future<List<Place>> removeSavedPlace(Place place) async {
    final places = await loadSavedPlaces();
    places.removeWhere((e) => _samePlace(e, place));
    await _writeSavedPlaces(places);
    return places;
  }

  // ----- Cached reading (offline) -----

  Future<void> saveCachedReading(AirQuality reading, String placeLabel) async {
    final p = await _prefs;
    await p.setString(_kCachedReading, jsonEncode(reading.toJson()));
    await p.setString(_kCachedPlaceLabel, placeLabel);
  }

  Future<AirQuality?> loadCachedReading() async {
    final p = await _prefs;
    final raw = p.getString(_kCachedReading);
    if (raw == null) return null;
    try {
      return AirQuality.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<String?> loadCachedPlaceLabel() async {
    final p = await _prefs;
    return p.getString(_kCachedPlaceLabel);
  }

  Future<void> saveCachedHourly(List<HourlyAqi> hourly) async {
    final p = await _prefs;
    await p.setString(
        _kCachedHourly, jsonEncode(hourly.map((h) => h.toJson()).toList()));
  }

  Future<List<HourlyAqi>> loadCachedHourly() async {
    final p = await _prefs;
    final raw = p.getString(_kCachedHourly);
    if (raw == null) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map<String, dynamic>>()
          .map(HourlyAqi.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ----- De-dupe background notifications -----

  Future<int?> lastNotifiedAqi() async {
    final p = await _prefs;
    return p.getInt(_kLastNotifiedAqi);
  }

  Future<void> setLastNotifiedAqi(int aqi) async {
    final p = await _prefs;
    await p.setInt(_kLastNotifiedAqi, aqi);
  }
}
