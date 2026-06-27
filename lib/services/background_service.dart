import 'package:workmanager/workmanager.dart';

import 'air_quality_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Periodic background AQI check via workmanager (§5.4). Best-effort,
/// especially on iOS; the on-open check in the UI is the guaranteed path.
const String kAqiCheckTask = 'airaware.aqiCheck';
const String kAqiCheckUnique = 'airaware.aqiCheck.periodic';

/// Entry point that runs in a background isolate. Must be top-level and
/// annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kAqiCheckTask) return true;
    try {
      final storage = StorageService();
      final prefs = await storage.loadPrefs();
      if (!prefs.alertsEnabled) return true;

      final place = await storage.loadLastPlace();
      if (place == null) return true;

      final reading = await AirQualityService().fetch(
        latitude: place.latitude,
        longitude: place.longitude,
      );

      // Cache so the UI shows fresh data on next open even if offline.
      await storage.saveCachedReading(reading, place.label);

      if (reading.usAqi > prefs.alertThreshold) {
        // Avoid re-spamming the same elevated reading.
        final lastNotified = await storage.lastNotifiedAqi();
        if (lastNotified == null || (reading.usAqi - lastNotified).abs() >= 1) {
          await NotificationService.instance.showAqiAlert(
            aqi: reading.usAqi,
            category: reading.band.category,
            placeLabel: place.label,
          );
          await storage.setLastNotifiedAqi(reading.usAqi);
        }
      } else {
        // Reset the de-dupe once we drop back below threshold.
        await storage.setLastNotifiedAqi(0);
      }
      return true;
    } catch (_) {
      // Returning false lets the OS retry later.
      return false;
    }
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
  }

  /// (Re)register the periodic check. Uses inexact periodic scheduling.
  static Future<void> registerDailyCheck() async {
    await Workmanager().registerPeriodicTask(
      kAqiCheckUnique,
      kAqiCheckTask,
      frequency: const Duration(hours: 8),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 30),
    );
  }

  static Future<void> cancelDailyCheck() async {
    await Workmanager().cancelByUniqueName(kAqiCheckUnique);
  }
}
