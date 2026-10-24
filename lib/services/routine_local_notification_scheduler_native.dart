import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:ui' show Color;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'routine_local_reminder.dart';

class RoutineLocalNotificationScheduler {
  static const _channelId = 'pbh_habit_routine';
  static const _notificationIds = <int>{
    47001,
    47101,
    47102,
    47103,
    47104,
    47105,
  };
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static bool get isSupported => true;

  static Future<void> _initialize() async {
    if (_initialized) return;
    timezone_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    timezone.setLocalLocation(timezone.getLocation(zone.identifier));
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_pbh_prominent'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await _initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final notificationsGranted =
          await android.requestNotificationsPermission() ?? false;
      if (!notificationsGranted) return false;

      // Exact, user-selected reminder times require Android's special
      // "Alarms & reminders" access on Android 12 and newer.
      final exactAlarmsGranted = await android.requestExactAlarmsPermission();
      return exactAlarmsGranted ??
          (await android.canScheduleExactNotifications() ?? false);
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  static Future<void> scheduleDaily(
    List<RoutineLocalReminder> reminders,
  ) async {
    await _initialize();
    for (final id in _notificationIds) {
      await _plugin.cancel(id);
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final canScheduleExactly = android == null
        ? false
        : await android.canScheduleExactNotifications() ?? false;
    final now = timezone.TZDateTime.now(timezone.local);
    for (final reminder in reminders) {
      var next = timezone.TZDateTime(
        timezone.local,
        now.year,
        now.month,
        now.day,
        reminder.time.hour,
        reminder.time.minute,
      );
      if (reminder.skipToday || !next.isAfter(now)) {
        final tomorrow = DateTime(
          now.year,
          now.month,
          now.day,
        ).add(const Duration(days: 1));
        next = timezone.TZDateTime(
          timezone.local,
          tomorrow.year,
          tomorrow.month,
          tomorrow.day,
          reminder.time.hour,
          reminder.time.minute,
        );
      }

      await _plugin.zonedSchedule(
        reminder.id,
        reminder.title,
        reminder.body,
        next,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            'Rotina de habitos',
            channelDescription:
                'Lembretes personalizados para cada tarefa da rotina.',
            importance: Importance.high,
            priority: Priority.high,
            icon: 'ic_stat_pbh_prominent',
            color: const Color(0xFF6D28D9),
            largeIcon: DrawableResourceAndroidBitmap(
              reminder.largeIconResource,
            ),
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: true,
            threadIdentifier: 'pbh-habit-routine',
          ),
        ),
        androidScheduleMode: canScheduleExactly
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'pbh://routine',
      );
    }
  }

  static Future<void> cancel() async {
    await _initialize();
    for (final id in _notificationIds) {
      await _plugin.cancel(id);
    }
  }
}
