import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Retain the request ID after an uncertain network result, including app restarts.
// This is retry bookkeeping, not an automatic background publication queue.
class CommentSubmissionStore {
  late final _storage = SharedPreferencesAsync();
  static Future<void> _tail = Future.value();
  Future<T> _serial<T>(Future<T> Function() work) {
    final result = _tail.then((_) => work());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  String _key(String user, String post, bool sample) =>
      'pbh.comment_submission.${Uri.encodeComponent(user)}.${sample ? 'sample' : 'post'}.${Uri.encodeComponent(post)}';

  Future<String> requestId(
    String user,
    String post,
    String content,
    String? reply,
    bool sample,
    String Function() generate,
  ) => _serial(() async {
    final key = _key(user, post, sample),
        raw = await _storage.getString(_key(user, post, sample));
    if (raw != null) {
      try {
        final previous = jsonDecode(raw) as Map<String, dynamic>;
        if (previous['content'] == content &&
            previous['reply'] == reply &&
            DateTime.now().difference(
                  DateTime.parse(previous['saved'] as String),
                ) <
                const Duration(days: 7) &&
            RegExp(r'^[0-9a-f-]{36}$').hasMatch(previous['id'] as String)) {
          return previous['id'] as String;
        }
      } catch (_) {
        /* Replace malformed local bookkeeping. */
      }
    }
    final id = generate();
    await _storage.setString(
      key,
      jsonEncode({
        'id': id,
        'content': content,
        'reply': reply,
        'saved': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    return id;
  });

  Future<void> acknowledged(
    String user,
    String post,
    bool sample,
    String content,
    String? reply,
  ) => _serial(() async {
    final key = _key(user, post, sample),
        raw = await _storage.getString(_key(user, post, sample));
    if (raw == null) return;
    final entry = jsonDecode(raw) as Map;
    if (entry['content'] == content && entry['reply'] == reply) {
      await _storage.remove(key);
    }
  });
}
