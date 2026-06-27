import '../models/air_quality.dart';
import '../models/forecast.dart';
import 'aqi.dart';

/// Pre-composed text for the daily morning/evening summary notifications.
class ReportContent {
  final String morningTitle;
  final String morningBody;
  final String eveningTitle;
  final String eveningBody;
  const ReportContent({
    required this.morningTitle,
    required this.morningBody,
    required this.eveningTitle,
    required this.eveningBody,
  });
}

/// The pollutant currently driving the AQI, with a plain-language note.
class DominantPollutant {
  final String label;
  final String note;
  final int aqi;
  const DominantPollutant(this.label, this.note, this.aqi);
}

/// A low-pollution time window coming up.
class CleanWindow {
  final DateTime start;
  final DateTime end;
  final int aqi;
  const CleanWindow(this.start, this.end, this.aqi);
}

class Insights {
  /// Pick the pollutant with the highest US-AQI sub-index. Returns null if no
  /// sub-indices were available.
  static DominantPollutant? dominant(AirQuality r) {
    final candidates = <MapEntry<String, int>>[
      if (r.pm25Aqi != null) MapEntry('pm2_5', r.pm25Aqi!),
      if (r.pm10Aqi != null) MapEntry('pm10', r.pm10Aqi!),
      if (r.ozoneAqi != null) MapEntry('ozone', r.ozoneAqi!),
      if (r.no2Aqi != null) MapEntry('no2', r.no2Aqi!),
    ];
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) => b.value.compareTo(a.value));
    final top = candidates.first;
    switch (top.key) {
      case 'pm2_5':
        return DominantPollutant('PM2.5',
            'Fine particles from smoke, vehicles and industry — they reach deep into the lungs.',
            top.value);
      case 'pm10':
        return DominantPollutant('PM10',
            'Coarse dust from roads, construction and soil.', top.value);
      case 'ozone':
        return DominantPollutant('Ozone',
            'Ground-level ozone — builds up on hot, sunny afternoons.', top.value);
      case 'no2':
        return DominantPollutant('NO₂',
            'Nitrogen dioxide — mostly traffic and combustion exhaust.', top.value);
      default:
        return null;
    }
  }

  /// Find the cleanest ~2-hour window in the next 24h, preferring daytime
  /// (06:00–21:00) so we don't suggest the middle of the night. Returns null
  /// if there isn't enough forecast data.
  static CleanWindow? bestCleanWindow(List<HourlyAqi> upcoming) {
    if (upcoming.length < 2) return null;

    final now = DateTime.now();
    final horizon = now.add(const Duration(hours: 24));
    final window = upcoming
        .where((h) => h.time.isAfter(now) && h.time.isBefore(horizon))
        .toList();
    if (window.length < 2) return null;

    bool isDay(DateTime t) => t.hour >= 6 && t.hour <= 21;

    // Score each adjacent 2h pair by average AQI; daytime pairs get priority.
    CleanWindow? best;
    double bestScore = double.infinity;
    for (var i = 0; i < window.length - 1; i++) {
      final a = window[i];
      final b = window[i + 1];
      final avg = (a.usAqi + b.usAqi) / 2;
      // Penalise night windows so daytime wins ties.
      final penalty = (isDay(a.time) && isDay(b.time)) ? 0 : 1000;
      final score = avg + penalty;
      if (score < bestScore) {
        bestScore = score;
        best = CleanWindow(a.time, b.time.add(const Duration(hours: 1)),
            ((a.usAqi + b.usAqi) / 2).round());
      }
    }
    return best;
  }

  /// Build morning + evening report text from the current reading + forecast.
  static ReportContent buildReports({
    required String placeLabel,
    required AirQuality current,
    required List<HourlyAqi> hourly,
    required bool sensitive,
  }) {
    final band = current.band;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    HourlyAqi? peakOn(DateTime day) {
      final pts = hourly.where((h) =>
          h.time.year == day.year &&
          h.time.month == day.month &&
          h.time.day == day.day);
      if (pts.isEmpty) return null;
      return pts.reduce((a, b) => a.usAqi >= b.usAqi ? a : b);
    }

    final todayPeak = peakOn(today);
    final tomorrowPeak = peakOn(tomorrow);
    final window = bestCleanWindow(
      hourly.where((h) => h.time.isAfter(now)).toList()
        ..sort((a, b) => a.time.compareTo(b.time)),
    );

    final care = sensitive && current.usAqi > 50
        ? ' Take it easy outdoors.'
        : '';

    // Morning
    final mb = StringBuffer(
        'Air is ${band.category} now (AQI ${current.usAqi}).');
    if (todayPeak != null) {
      mb.write(
          ' Today\'s peak ~${todayPeak.usAqi} around ${_clock(todayPeak.time)}.');
    }
    if (window != null) {
      mb.write(' Cleanest air ${_clock(window.start)}–${_clock(window.end)}.');
    }
    mb.write(care);

    // Evening
    final eb = StringBuffer(
        'Air is ${band.category} (AQI ${current.usAqi}).');
    if (tomorrowPeak != null) {
      final tb = AqiBand.forValue(tomorrowPeak.usAqi);
      eb.write(
          ' Tomorrow\'s peak ~${tomorrowPeak.usAqi} (${tb.category}).');
    }
    eb.write(care);

    return ReportContent(
      morningTitle: 'Good morning · $placeLabel',
      morningBody: mb.toString(),
      eveningTitle: 'This evening · $placeLabel',
      eveningBody: eb.toString(),
    );
  }

  static String _clock(DateTime t) {
    final isPm = t.hour >= 12;
    var h = t.hour % 12;
    if (h == 0) h = 12;
    return '$h ${isPm ? 'PM' : 'AM'}';
  }
}
