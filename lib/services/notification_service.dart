import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Local-notification setup + a helper to fire an AQI alert. Safe to call
/// from both the UI isolate and the workmanager background isolate.
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String channelId = 'airaware_alerts';
  static const String channelName = 'Air quality alerts';
  static const String channelDesc =
      'Notifies you when the air near you turns unhealthy.';

  bool _initialised = false;

  Future<void> init() async {
    if (_initialised) return;

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    // Create the Android channel up-front.
    final androidImpl =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDesc,
        importance: Importance.high,
      ),
    );

    _initialised = true;
  }

  /// Request notification permission at the right time (Android 13+ / iOS).
  Future<bool> requestPermission() async {
    await init();
    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    } else if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  static const int _morningId = 2001;
  static const int _eveningId = 2002;

  /// Schedule a daily morning (07:00) and evening (18:00) summary that repeats
  /// at the same time each day. Content reflects the latest forecast and is
  /// refreshed whenever the app reschedules. Uses inexact scheduling so no
  /// exact-alarm permission is needed.
  Future<void> scheduleDailyReports({
    required String tzName,
    required String morningTitle,
    required String morningBody,
    required String eveningTitle,
    required String eveningBody,
  }) async {
    await init();
    try {
      if (tzName.isNotEmpty) {
        tz.setLocalLocation(tz.getLocation(tzName));
      }
    } catch (_) {
      // Fall back to whatever local zone is set.
    }

    await _scheduleAt(_morningId, 7, 0, morningTitle, morningBody);
    await _scheduleAt(_eveningId, 18, 0, eveningTitle, eveningBody);
  }

  Future<void> cancelDailyReports() async {
    await init();
    await _plugin.cancel(id: _morningId);
    await _plugin.cancel(id: _eveningId);
  }

  Future<void> _scheduleAt(
    int id,
    int hour,
    int minute,
    String title,
    String body,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDesc,
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
        styleInformation: BigTextStyleInformation(''),
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: when,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );
  }

  Future<void> showAqiAlert({
    required int aqi,
    required String category,
    required String placeLabel,
  }) async {
    await init();
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.show(
      id: 1001,
      title: 'Air quality alert — $category',
      body: 'AQI is $aqi near $placeLabel. Tap to see what to do.',
      notificationDetails:
          const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }
}
