import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'community_post_navigation.dart';

class ChatNavigation {
  static final pending = ValueNotifier<String?>(null);
  static String? activeThread;
  static String? fromUrl(String? value) {
    final uri = Uri.tryParse(value ?? '');
    if (uri?.scheme != 'https' || uri?.host != 'pbh-oficial.vercel.app')
      return null;
    final id = uri!.queryParameters['chat'];
    return id != null && validCommunityPostId(id) ? id : null;
  }

  static void fromNotification(Map<String, dynamic> data, String? user) {
    if (user == null || data['recipient_id'] != user) return;
    final id = fromUrl(data['destination_url'] as String?);
    if (id != null) pending.value = id;
  }

  static void fromLocalPayload(String? value, String? user) {
    try {
      fromNotification(
        Map<String, dynamic>.from(jsonDecode(value ?? '{}') as Map),
        user,
      );
    } catch (_) {}
  }
}
