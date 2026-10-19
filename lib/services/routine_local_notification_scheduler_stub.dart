import 'routine_local_reminder.dart';

class RoutineLocalNotificationScheduler {
  static bool get isSupported => false;

  static Future<bool> requestPermission() async => false;

  static Future<void> scheduleDaily(
      List<RoutineLocalReminder> reminders) async {}

  static Future<void> cancel() async {}
}
