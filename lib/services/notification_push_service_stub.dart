class NotificationPushService {
  static bool get isSupported => false;
  static bool get isConfigured => false;
  static Future<void> subscribe() async => throw UnsupportedError('Notificações push estão disponíveis na versão web.');
}
