import 'dart:convert';
import 'dart:js_interop';

import 'package:supabase_flutter/supabase_flutter.dart';

@JS('pbhGetPushSubscription')
external JSPromise<JSString> _getBrowserSubscription(JSString vapidPublicKey);

class NotificationPushService {
  static const _vapidPublicKey = String.fromEnvironment('WEB_PUSH_VAPID_PUBLIC_KEY');
  static bool get isSupported => true;
  static bool get isConfigured => _vapidPublicKey.isNotEmpty;

  static Future<void> subscribe() async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw StateError('Entre na sua conta para ativar notificações.');
    if (!isConfigured) throw StateError('A chave pública VAPID ainda não foi configurada no build web.');

    final jsonString = (await _getBrowserSubscription(_vapidPublicKey.toJS).toDart).toDart;
    final subscription = jsonDecode(jsonString) as Map<String, dynamic>;
    final keys = subscription['keys'] as Map<String, dynamic>;
    final endpoint = subscription['endpoint'] as String;
    final existing = await client.from('web_push_subscriptions').select('endpoint').eq('user_id', userId).eq('endpoint', endpoint).maybeSingle();
    if (existing != null) return;
    await client.from('web_push_subscriptions').insert({
      'user_id': userId,
      'endpoint': endpoint,
      'p256dh': keys['p256dh'],
      'auth': keys['auth'],
    });
  }
}
