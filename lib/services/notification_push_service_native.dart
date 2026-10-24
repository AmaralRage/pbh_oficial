import 'mobile_push_service.dart';

class NotificationPushService {
  static bool get isSupported => MobilePushService.isSupported;
  static bool get isConfigured => MobilePushService.isConfigured;
  static Future<void> subscribe() => MobilePushService.subscribe();
}
