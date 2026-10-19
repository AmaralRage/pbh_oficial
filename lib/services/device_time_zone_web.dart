import 'dart:js_interop';

@JS('pbhGetTimeZone')
external JSString _getBrowserTimeZone();

class DeviceTimeZone {
  static Future<String> current() async => _getBrowserTimeZone().toDart;
}
