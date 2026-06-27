import 'package:flutter/material.dart';

/// US AQI band logic — the single source of truth for category, color and
/// plain-language verdicts (§6 of the spec). Do not invent values elsewhere;
/// always go through [AqiBand].
class AqiBand {
  final int min;
  final int max; // inclusive; 999999 acts as "and above"
  final String category;
  final Color color;
  final String normalVerdict;
  final String sensitiveVerdict;

  const AqiBand({
    required this.min,
    required this.max,
    required this.category,
    required this.color,
    required this.normalVerdict,
    required this.sensitiveVerdict,
  });

  /// Returns the verdict for the given sensitivity setting.
  String verdict({required bool sensitive}) =>
      sensitive ? sensitiveVerdict : normalVerdict;

  /// All bands in ascending order (§6 table).
  static const List<AqiBand> bands = [
    AqiBand(
      min: 0,
      max: 50,
      category: 'Good',
      color: Color(0xFF4CAF50),
      normalVerdict: 'Air is clean. Great day to be outside.',
      sensitiveVerdict: 'Air is clean — fine for everyone.',
    ),
    AqiBand(
      min: 51,
      max: 100,
      category: 'Moderate',
      color: Color(0xFFFFC107),
      normalVerdict:
          'Mostly fine. Very sensitive people should take it easy.',
      sensitiveVerdict: 'Take it easy outdoors; keep activity shorter.',
    ),
    AqiBand(
      min: 101,
      max: 150,
      category: 'Unhealthy for Sensitive Groups',
      color: Color(0xFFFF9800),
      normalVerdict:
          'Sensitive people should limit long outdoor effort.',
      sensitiveVerdict:
          'Limit time outside; keep your reliever inhaler handy.',
    ),
    AqiBand(
      min: 151,
      max: 200,
      category: 'Unhealthy',
      color: Color(0xFFF44336),
      normalVerdict: 'Avoid outdoor exercise. Keep windows closed.',
      sensitiveVerdict: 'Stay indoors; wear a mask if you must go out.',
    ),
    AqiBand(
      min: 201,
      max: 300,
      category: 'Very Unhealthy',
      color: Color(0xFF9C27B0),
      normalVerdict: 'Stay indoors if you can. Wear a mask outside.',
      sensitiveVerdict: 'Stay indoors. Avoid any outdoor exposure.',
    ),
    AqiBand(
      min: 301,
      max: 999999,
      category: 'Hazardous',
      color: Color(0xFF7E0023),
      normalVerdict: 'Health alert. Avoid all outdoor activity.',
      sensitiveVerdict: 'Health emergency. Do not go outside.',
    ),
  ];

  /// Resolve the band for a given AQI value. Negative values clamp to Good.
  static AqiBand forValue(int aqi) {
    final v = aqi < 0 ? 0 : aqi;
    for (final band in bands) {
      if (v >= band.min && v <= band.max) return band;
    }
    return bands.last; // safety: anything huge is Hazardous
  }
}
