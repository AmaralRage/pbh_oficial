import 'package:flutter_timezone/flutter_timezone.dart';

class DeviceTimeZone {
  static Future<String> current() async =>
      (await FlutterTimezone.getLocalTimezone()).identifier;
}
