import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/air_quality.dart';
import '../models/forecast.dart';

/// Fetches current air quality + hourly forecast from the Open-Meteo Air
/// Quality API (no key).
class AirQualityService {
  static const _base = 'https://air-quality-api.open-meteo.com/v1/air-quality';

  final http.Client _client;
  AirQualityService({http.Client? client}) : _client = client ?? http.Client();

  /// Current reading only (kept for the lightweight background isolate path).
  Future<AirQuality> fetch({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _get(latitude: latitude, longitude: longitude);
    return AirQuality.fromApi(json);
  }

  /// Current reading + per-pollutant sub-indices + 7-day hourly US-AQI.
  Future<AirBundle> fetchBundle({
    required double latitude,
    required double longitude,
  }) async {
    final json = await _get(
      latitude: latitude,
      longitude: longitude,
      withForecast: true,
    );
    final current = AirQuality.fromApi(json);
    return AirBundle(
      current: current,
      hourly: _parseHourly(json),
      timezone: (json['timezone'] as String?) ?? '',
    );
  }

  Future<Map<String, dynamic>> _get({
    required double latitude,
    required double longitude,
    bool withForecast = false,
  }) async {
    final params = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'us_aqi,pm2_5,pm10,ozone,nitrogen_dioxide,'
          'us_aqi_pm2_5,us_aqi_pm10,us_aqi_ozone,us_aqi_nitrogen_dioxide',
      'timezone': 'auto',
    };
    if (withForecast) {
      params['hourly'] = 'us_aqi';
      params['forecast_days'] = '7';
    }

    final uri = Uri.parse(_base).replace(queryParameters: params);
    final res = await _client.get(uri).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      throw Exception('Air quality request failed (${res.statusCode})');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json['current'] == null) {
      throw Exception('No air-quality data for this location.');
    }
    return json;
  }

  List<HourlyAqi> _parseHourly(Map<String, dynamic> json) {
    final hourly = json['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return const [];
    final times = (hourly['time'] as List?) ?? const [];
    final values = (hourly['us_aqi'] as List?) ?? const [];
    final out = <HourlyAqi>[];
    for (var i = 0; i < times.length && i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final t = DateTime.tryParse(times[i].toString());
      if (t == null) continue;
      out.add(HourlyAqi(t, (v as num).round()));
    }
    return out;
  }
}
