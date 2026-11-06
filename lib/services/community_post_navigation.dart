import 'package:flutter/foundation.dart';
import 'dart:convert';

bool validCommunityPostId(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$',
).hasMatch(value);
String? communityPostFromNotificationUrl(String? value) {
  final uri = Uri.tryParse(value ?? '');
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host != 'pbh-oficial.vercel.app')
    return null;
  final id = uri.queryParameters['community_post'];
  return id != null && validCommunityPostId(id) ? id : null;
}

class CommunityPostNavigation {
  static final pending = ValueNotifier<String?>(null);
  static void fromLocalPayload(String? payload, String? currentUser) {
    try {
      fromNotification(
        Map<String, dynamic>.from(jsonDecode(payload ?? '{}') as Map),
        currentUser,
      );
    } catch (_) {}
  }

  static void fromNotification(Map<String, dynamic> data, String? currentUser) {
    if (currentUser == null || data['recipient_id'] != currentUser) return;
    final id = communityPostFromNotificationUrl(
      data['destination_url'] is String
          ? data['destination_url'] as String
          : null,
    );
    if (id != null) pending.value = id;
  }
}
