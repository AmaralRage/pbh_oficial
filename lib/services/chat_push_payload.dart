import 'chat_navigation.dart';
import 'community_post_navigation.dart';

class ChatPushPayload {
  ChatPushPayload._(
    this.data,
    this.threadId,
    this.messageId,
    this.senderId,
    this.recipientId,
    this.name,
    this.preview,
    this.sentAt,
    this.expiresAt,
  );
  final Map<String, dynamic> data;
  final String threadId, messageId, senderId, recipientId, name, preview;
  final DateTime sentAt, expiresAt;
  String? get avatar =>
      data['avatar_url'] is String ? data['avatar_url'] as String : null;
  bool get founder => data['sender_founder'] == 'true';
  bool get silent => data['silent'] == 'true';
  int get notificationId {
    var hash = 0x811c9dc5;
    for (final code in threadId.codeUnits) {
      hash = ((hash ^ code) * 0x01000193) & 0x7fffffff;
    }
    return 1000000 + hash % 1000000000;
  }

  static ChatPushPayload? parse(Map<String, dynamic> data) {
    final thread = ChatNavigation.fromUrl(data['destination_url'] as String?);
    final sender = data['sender_id'],
        recipient = data['recipient_id'],
        message = data['message_id'];
    if (thread == null ||
        data['chat_id'] != thread ||
        sender is! String ||
        recipient is! String ||
        message is! String ||
        ![sender, recipient, message].every(validCommunityPostId))
      return null;
    final sent = DateTime.tryParse(data['sent_at'] as String? ?? ''),
        expires = DateTime.tryParse(data['expires_at'] as String? ?? '');
    if (sent == null || expires == null || !expires.isAfter(DateTime.now()))
      return null;
    final name = data['sender_name'], body = data['preview'];
    if (name is! String ||
        body is! String ||
        name.trim().isEmpty ||
        name.length > 40 ||
        body.length > 240)
      return null;
    return ChatPushPayload._(
      data,
      thread,
      message,
      sender,
      recipient,
      name,
      body,
      sent,
      expires,
    );
  }
}
