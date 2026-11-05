import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CommentDraftStore {
  CommentDraftStore({SharedPreferencesAsync? storage})
    : _providedStorage = storage;
  final SharedPreferencesAsync? _providedStorage;
  late final SharedPreferencesAsync _storage =
      _providedStorage ?? SharedPreferencesAsync();
  String _key(String user, String post) =>
      'pbh.comment_draft.${Uri.encodeComponent(user)}.${Uri.encodeComponent(post)}';
  Future<String?> load(String user, String post) async {
    final key = _key(user, post),
        raw = await _storage.getString(_key(user, post));
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final date = DateTime.parse(data['saved'] as String);
      final text = data['text'] as String;
      if (DateTime.now().difference(date) > const Duration(days: 7) ||
          text.length > 2000) {
        await _storage.remove(key);
        return null;
      }
      return text;
    } catch (_) {
      await _storage.remove(key);
      return null;
    }
  }

  Future<void> save(String user, String post, String text) async {
    final key = _key(user, post);
    if (text.trim().isEmpty) {
      await _storage.remove(key);
      return;
    }
    await _storage.setString(
      key,
      jsonEncode({
        'text': text.length > 2000 ? text.substring(0, 2000) : text,
        'saved': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }
}
