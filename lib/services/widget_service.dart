import 'package:home_widget/home_widget.dart';

import '../models/air_quality.dart';

/// Pushes the latest reading to the Android home-screen widget.
class WidgetService {
  static const _androidProvider = 'AqiWidgetProvider';

  /// Save the current reading + place into widget storage and refresh the
  /// widget. Safe to call even if no widget is placed (no-op then).
  static Future<void> update({
    required AirQuality reading,
    required String placeName,
  }) async {
    final band = reading.band;
    // Pack ARGB as a *signed* 32-bit int. The unsigned 0xFFRRGGBB value
    // exceeds int range and would be stored as a long, which the Android
    // RemoteViews code can't read back with getInt(). toSigned(32) keeps it
    // an int and is still a valid Android color value.
    final colorValue = band.color.toARGB32().toSigned(32);
    try {
      await HomeWidget.saveWidgetData<int>('aqi', reading.usAqi);
      await HomeWidget.saveWidgetData<String>('category', band.category);
      await HomeWidget.saveWidgetData<String>('place', placeName);
      await HomeWidget.saveWidgetData<int>('color', colorValue);
      await HomeWidget.updateWidget(androidName: _androidProvider);
    } catch (_) {
      // Widget not available on this platform / not added — ignore.
    }
  }
}
