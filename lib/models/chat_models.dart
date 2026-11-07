import 'dart:typed_data';

class ChatThread {
  const ChatThread({
    required this.id,
    required this.peerId,
    required this.name,
    this.avatar,
    this.founder = false,
    this.handle,
    this.preview = '',
    this.hasImage = false,
    required this.lastAt,
    required this.activityAt,
    this.lastSender,
    this.unread = 0,
    required this.peerReadAt,
  });
  final String id, peerId, name, preview;
  final String? avatar, handle, lastSender;
  final bool hasImage;
  final bool founder;
  final int unread;
  final DateTime lastAt, activityAt, peerReadAt;
  factory ChatThread.fromMap(Map<String, dynamic> m) => ChatThread(
    id: m['thread_id'] as String,
    peerId: m['peer_id'] as String,
    name: m['name'] as String? ?? 'Membro',
    avatar: m['avatar_url'] as String?,
    founder: m['founder'] == true,
    handle: m['handle'] as String?,
    preview: m['last_body'] as String? ?? '',
    hasImage: m['last_image'] == true,
    lastAt: DateTime.parse(m['last_at'] as String).toLocal(),
    activityAt: DateTime.parse(m['activity_at'] as String),
    lastSender: m['last_sender'] as String?,
    unread: (m['unread'] as num?)?.toInt() ?? 0,
    peerReadAt: DateTime.parse(m['peer_read_at'] as String),
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    required this.expiresAt,
    this.imagePath,
    this.imageUrl,
    this.replyTo,
  });
  final String id, senderId, body;
  final String? imagePath, imageUrl, replyTo;
  final DateTime createdAt, expiresAt;
  factory ChatMessage.fromMap(Map<String, dynamic> m, {String? imageUrl}) =>
      ChatMessage(
        id: m['id'] as String,
        senderId: m['sender_id'] as String,
        body: m['body'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        expiresAt: DateTime.parse(m['expires_at'] as String),
        imagePath: m['image_path'] as String?,
        imageUrl: imageUrl,
        replyTo: m['reply_to'] as String?,
      );
}

class ChatDraft {
  const ChatDraft({
    required this.id,
    required this.text,
    this.photo,
    this.replyId,
  });
  final String id, text;
  final Uint8List? photo;
  final String? replyId;
}
