import '../utils/aqi.dart';

/// A single air-quality reading parsed from the Open-Meteo Air Quality API.
class AirQuality {
  final int usAqi;
  final double? pm25;
  final double? pm10;
  final double? ozone;
  final double? no2;

  /// Per-pollutant US AQI sub-indices (used to find the dominant pollutant).
  /// Null when not requested/available.
  final int? pm25Aqi;
  final int? pm10Aqi;
  final int? ozoneAqi;
  final int? no2Aqi;

  /// Raw API time string, e.g. "2026-06-27T10:00".
  final String time;

  const AirQuality({
    required this.usAqi,
    required this.pm25,
    required this.pm10,
    required this.ozone,
    required this.no2,
    required this.time,
    this.pm25Aqi,
    this.pm10Aqi,
    this.ozoneAqi,
    this.no2Aqi,
  });

  AqiBand get band => AqiBand.forValue(usAqi);

  /// Parse from the full API JSON (expects a `current` object).
  factory AirQuality.fromApi(Map<String, dynamic> json) {
    final current = (json['current'] as Map<String, dynamic>?) ?? const {};
    return AirQuality(
      usAqi: _toInt(current['us_aqi']),
      pm25: _toDouble(current['pm2_5']),
      pm10: _toDouble(current['pm10']),
      ozone: _toDouble(current['ozone']),
      no2: _toDouble(current['nitrogen_dioxide']),
      pm25Aqi: _toIntOrNull(current['us_aqi_pm2_5']),
      pm10Aqi: _toIntOrNull(current['us_aqi_pm10']),
      ozoneAqi: _toIntOrNull(current['us_aqi_ozone']),
      no2Aqi: _toIntOrNull(current['us_aqi_nitrogen_dioxide']),
      time: (current['time'] as String?) ?? '',
    );
  }

  /// For caching in shared_preferences.
  Map<String, dynamic> toJson() => {
        'us_aqi': usAqi,
        'pm2_5': pm25,
        'pm10': pm10,
        'ozone': ozone,
        'nitrogen_dioxide': no2,
        'us_aqi_pm2_5': pm25Aqi,
        'us_aqi_pm10': pm10Aqi,
        'us_aqi_ozone': ozoneAqi,
        'us_aqi_nitrogen_dioxide': no2Aqi,
        'time': time,
      };

  factory AirQuality.fromJson(Map<String, dynamic> json) => AirQuality(
        usAqi: _toInt(json['us_aqi']),
        pm25: _toDouble(json['pm2_5']),
        pm10: _toDouble(json['pm10']),
        ozone: _toDouble(json['ozone']),
        no2: _toDouble(json['nitrogen_dioxide']),
        pm25Aqi: _toIntOrNull(json['us_aqi_pm2_5']),
        pm10Aqi: _toIntOrNull(json['us_aqi_pm10']),
        ozoneAqi: _toIntOrNull(json['us_aqi_ozone']),
        no2Aqi: _toIntOrNull(json['us_aqi_nitrogen_dioxide']),
        time: (json['time'] as String?) ?? '',
      );

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static int? _toIntOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is String) return int.tryParse(v);
    return null;
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }
}
