export 'device_time_zone_stub.dart'
    if (dart.library.io) 'device_time_zone_native.dart'
    if (dart.library.js_interop) 'device_time_zone_web.dart';
