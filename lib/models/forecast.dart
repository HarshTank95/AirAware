import '../utils/aqi.dart';
import 'air_quality.dart';

/// One hourly US-AQI forecast point.
class HourlyAqi {
  final DateTime time;
  final int usAqi;
  const HourlyAqi(this.time, this.usAqi);

  AqiBand get band => AqiBand.forValue(usAqi);

  Map<String, dynamic> toJson() => {'t': time.toIso8601String(), 'a': usAqi};

  factory HourlyAqi.fromJson(Map<String, dynamic> j) =>
      HourlyAqi(DateTime.parse(j['t'] as String), (j['a'] as num).round());
}

/// A daily roll-up (peak AQI of the day) derived from hourly points.
class DailyAqi {
  final DateTime date;
  final int peakAqi;
  const DailyAqi(this.date, this.peakAqi);

  AqiBand get band => AqiBand.forValue(peakAqi);
}

/// Everything one fetch returns: the current reading + the hourly forecast.
class AirBundle {
  final AirQuality current;
  final List<HourlyAqi> hourly;

  /// IANA timezone name from the API (e.g. "Asia/Kolkata"), used to schedule
  /// time-of-day notifications. Empty if unknown.
  final String timezone;

  const AirBundle({
    required this.current,
    required this.hourly,
    this.timezone = '',
  });

  /// Hourly points from [from] onward (defaults to now), in time order.
  List<HourlyAqi> upcoming({DateTime? from}) {
    final start = from ?? DateTime.now();
    final cutoff = start.subtract(const Duration(minutes: 59));
    return hourly.where((h) => h.time.isAfter(cutoff)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// Daily peak AQI for the next [days] days (today included).
  List<DailyAqi> dailyPeaks({int days = 7}) {
    final byDay = <DateTime, int>{};
    for (final h in hourly) {
      final d = DateTime(h.time.year, h.time.month, h.time.day);
      byDay[d] = byDay.containsKey(d) ? (h.usAqi > byDay[d]! ? h.usAqi : byDay[d]!) : h.usAqi;
    }
    final entries = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return entries.take(days).map((e) => DailyAqi(e.key, e.value)).toList();
  }
}
