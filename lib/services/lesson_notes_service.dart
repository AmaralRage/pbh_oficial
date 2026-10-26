import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LessonNotesService {
  LessonNotesService({SupabaseClient? client, SharedPreferencesAsync? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? SharedPreferencesAsync() {
    _account = _client.auth.currentUser?.id ?? 'guest';
  }
  final SupabaseClient _client;
  final SharedPreferencesAsync _storage;
  late final String _account;
  void _check() {
    if ((_client.auth.currentUser?.id ?? 'guest') != _account) {
      throw StateError('A conta mudou. Abra novamente a aula.');
    }
  }

  String _key(String program, String lesson) =>
      'pbh.notes.$_account.${Uri.encodeComponent(jsonEncode([program, lesson]))}';
  Future<String> load(String program, String lesson) async {
    _check();
    final text = await _storage.getString(_key(program, lesson));
    _check();
    return text ?? '';
  }

  Future<void> save(String program, String lesson, String text) async {
    _check();
    if (text.length > 6000) {
      throw ArgumentError('A anotação pode ter até 6000 caracteres.');
    }
    await _storage.setString(_key(program, lesson), text);
    _check();
  }
}
