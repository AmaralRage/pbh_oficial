import 'dart:convert';
import 'dart:typed_data';
import '../models/chat_models.dart';
import 'community_draft_storage.dart' as storage;

class ChatLocalStore {
  static Future<void> _pending = Future.value();
  String _key(String user, String thread, String kind) => base64UrlEncode(
    utf8.encode('private-chat:$kind:$user:$thread'),
  ).replaceAll('=', '');
  Future<ChatDraft?> load(String user, String thread) async {
    final raw = await storage.readDraft(_key(user, thread, 'draft'));
    if (raw == null) return null;
    try {
      if (raw.length > 1500000) throw const FormatException();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (DateTime.now().difference(DateTime.parse(data['saved'] as String)) >
              const Duration(days: 7) ||
          (data['text'] as String).length > 2000 ||
          !RegExp(r'^[0-9a-f-]{36}$').hasMatch(data['id'] as String))
        throw const FormatException();
      final photo = data['photo'] == null
          ? null
          : base64Decode(data['photo'] as String);
      if (photo != null && photo.length > 512 * 1024)
        throw const FormatException();
      ChatVoice? voice;
      if (data['audio'] != null) {
        final bytes = base64Decode(data['audio'] as String);
        final duration = data['audio_duration'] as int;
        final format = data['audio_format'] as String;
        if (bytes.isEmpty ||
            bytes.length > 1048576 ||
            duration < 1 ||
            duration > 120000 ||
            !['m4a', 'webm'].contains(format) ||
            photo != null ||
            (data['text'] as String).trim().isNotEmpty)
          throw const FormatException();
        voice = ChatVoice(bytes: bytes, format: format, durationMs: duration);
      }
      return ChatDraft(
        id: data['id'] as String,
        text: data['text'] as String,
        photo: photo,
        replyId: data['reply'] as String?,
        voice: voice,
      );
    } catch (_) {
      await storage.removeDraft(_key(user, thread, 'draft'));
      return null;
    }
  }

  Future<void> save(String user, String thread, ChatDraft draft) {
    final task = _pending.then((_) async {
      final key = _key(user, thread, 'draft');
      if (draft.text.trim().isEmpty &&
          draft.photo == null &&
          draft.voice == null) {
        await storage.removeDraft(key);
        return;
      }
      await storage.writeDraft(
        key,
        jsonEncode({
          'id': draft.id,
          'text': draft.text,
          'photo': draft.photo == null ? null : base64Encode(draft.photo!),
          'reply': draft.replyId,
          'audio': draft.voice == null
              ? null
              : base64Encode(draft.voice!.bytes),
          'audio_format': draft.voice?.format,
          'audio_duration': draft.voice?.durationMs,
          'saved': DateTime.now().toUtc().toIso8601String(),
        }),
      );
    });
    _pending = task.catchError((Object _) {});
    return task;
  }

  Future<Map<String, dynamic>> wallpaper(String user, String thread) async {
    try {
      final raw = await storage.readDraft(_key(user, thread, 'wallpaper'));
      if (raw == null || raw.length > 800000) return {};
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  Future<void> saveWallpaper(
    String user,
    String thread,
    String preset,
    Uint8List? photo, {
    double dim = .54,
  }) => storage.writeDraft(
    _key(user, thread, 'wallpaper'),
    jsonEncode({
      'preset': preset,
      'photo': photo == null ? null : base64Encode(photo),
      'dim': dim.clamp(0, .85),
    }),
  );
}
