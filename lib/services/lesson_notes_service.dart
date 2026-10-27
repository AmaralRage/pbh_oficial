import 'dart:convert';
import 'dart:async';
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
  bool syncPending = false;
  bool get canSync => _account != 'guest';
  bool conflict = false;
  Object? lastSyncError;
  final Map<String, int> _revisions = {};
  static final _queues = <String, Future<void>>{};
  Future<T> _serial<T>(String key, Future<T> Function() action) async {
    final previous = _queues[key] ?? Future<void>.value();
    final done = Completer<void>();
    _queues[key] = done.future;
    await previous;
    try {
      _check();
      return await action();
    } finally {
      done.complete();
      if (identical(_queues[key], done.future)) _queues.remove(key);
    }
  }

  void _check() {
    if ((_client.auth.currentUser?.id ?? 'guest') != _account) {
      throw StateError('A conta mudou. Abra novamente a aula.');
    }
  }

  String _key(String program, String lesson) =>
      'pbh.notes.$_account.${Uri.encodeComponent(jsonEncode([program, lesson]))}';
  Future<String> load(
    String program,
    String lesson,
  ) => _serial(_key(program, lesson), () async {
    _check();
    final key = _key(program, lesson);
    final local = await _storage.getString(key);
    final pending = await _storage.getBool('$key.pending') ?? false;
    _revisions[key] = await _storage.getInt('$key.revision') ?? 0;
    syncPending = false;
    conflict = false;
    if (_account == 'guest') return local ?? '';
    if (pending) {
      await _push(program, lesson, local ?? '');
      return local ?? '';
    }
    try {
      final row = await _client
          .from('lesson_notes')
          .select()
          .eq('user_id', _account)
          .eq('program_id', program)
          .eq('lesson_id', lesson)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      _check();
      if (row != null) {
        // Preserve pre-sync local notes if another device already has a version.
        if (local != null &&
            local.isNotEmpty &&
            _revisions[key] == 0 &&
            local != row['content']) {
          await _storage.setBool('$key.pending', true);
          syncPending = true;
          conflict = true;
          return local;
        }
        final content = row['content'] as String;
        _revisions[key] = (row['revision'] as num).toInt();
        await _storage.setInt('$key.revision', _revisions[key]!);
        await _storage.setString(key, content);
        return content;
      }
      if (local != null && local.isNotEmpty) {
        await _storage.setBool('$key.pending', true);
        await _push(program, lesson, local);
      }
    } catch (_) {
      _check();
      syncPending = true;
    }
    _check();
    return local ?? '';
  });

  Future<void> save(String program, String lesson, String text) =>
      _serial(_key(program, lesson), () async {
        _check();
        if (text.length > 6000) {
          throw ArgumentError('A anotação pode ter até 6000 caracteres.');
        }
        await _storage.setString(_key(program, lesson), text);
        _check();
        if (_account != 'guest') {
          await _storage.setBool('${_key(program, lesson)}.pending', true);
          await _push(program, lesson, text);
        }
      });

  Future<void> _push(String program, String lesson, String text) async {
    final key = _key(program, lesson);
    syncPending = true;
    conflict = false;
    lastSyncError = null;
    try {
      final revision =
          _revisions[key] ?? await _storage.getInt('$key.revision') ?? 0;
      final result = await _client
          .rpc(
            'save_lesson_note',
            params: {
              'p_program_id': program,
              'p_lesson_id': lesson,
              'p_content': text,
              'p_revision': revision,
            },
          )
          .timeout(const Duration(seconds: 8));
      _check();
      if (result['conflict'] == true) {
        conflict = true;
        return;
      }
      final next = (result['note']['revision'] as num).toInt();
      _revisions[key] = next;
      await _storage.setInt('$key.revision', next);
      await _storage.setBool('$key.pending', false);
      syncPending = false;
    } catch (error) {
      lastSyncError = error;
      _check();
    }
  }

  // Conflict resolution is explicit: the editor confirms before replacing its draft.
  Future<String> useRemote(String program, String lesson) =>
      _serial(_key(program, lesson), () async {
        final row = await _client
            .from('lesson_notes')
            .select()
            .eq('user_id', _account)
            .eq('program_id', program)
            .eq('lesson_id', lesson)
            .single()
            .timeout(const Duration(seconds: 8));
        _check();
        final key = _key(program, lesson);
        // Retain the draft locally even after choosing the remote version.
        await _storage.setString(
          '$key.conflict_backup',
          await _storage.getString(key) ?? '',
        );
        final content = row['content'] as String;
        _revisions[key] = (row['revision'] as num).toInt();
        await _storage.setInt('$key.revision', _revisions[key]!);
        await _storage.setString(key, content);
        await _storage.setBool('$key.pending', false);
        syncPending = false;
        conflict = false;
        return content;
      });
}
