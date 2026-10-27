import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/program_model.dart';
import 'lesson_notes_service.dart';

class ProgramProgress {
  const ProgramProgress({
    this.saved = false,
    this.started = false,
    this.completed = const {},
    this.savedAt = '',
    this.openedAt = '',
    this.pending = false,
    this.completedAt = const {},
  });
  final bool saved;
  final bool started;
  final Set<String> completed;
  final String savedAt;
  final String openedAt;
  final bool pending;
  // Datas sincronizadas quando conhecidas; conclusões antigas não recebem datas inventadas.
  final Map<String, String> completedAt;
  int completedCount(ProgramModel program) =>
      program.lessons.where((l) => completed.contains(l.id)).length;
  bool isComplete(ProgramModel program) =>
      program.lessons.isNotEmpty &&
      completedCount(program) == program.lessons.length;
  String? nextLessonId(ProgramModel program) {
    for (final lesson in program.lessons) {
      if (!completed.contains(lesson.id)) return lesson.id;
    }
    return null;
  }

  factory ProgramProgress.fromJson(Map<String, dynamic> json) =>
      ProgramProgress(
        saved: json['saved'] == true,
        started: json['started'] == true,
        completed: Set<String>.from(json['completed'] as List? ?? []),
        savedAt: _normalizedTime(json['saved_at']),
        openedAt: _normalizedTime(json['opened_at']),
        pending: json['pending'] == true,
        completedAt: Map<String, String>.from(
          json['completed_at'] as Map? ?? {},
        ),
      );
  static String _normalizedTime(dynamic value) =>
      DateTime.tryParse(value as String? ?? '')?.toUtc().toIso8601String() ??
      '';
  Map<String, dynamic> toJson() => {
    'saved': saved,
    'started': started,
    'completed': completed.toList(),
    'saved_at': savedAt,
    'opened_at': openedAt,
    'pending': pending,
    'completed_at': completedAt,
  };
  ProgramProgress merge(ProgramProgress other) => ProgramProgress(
    saved: savedAt.compareTo(other.savedAt) > 0 ? saved : other.saved,
    savedAt: savedAt.compareTo(other.savedAt) > 0 ? savedAt : other.savedAt,
    started: started || other.started,
    completed: {...completed, ...other.completed},
    completedAt: {
      for (final id in {...completedAt.keys, ...other.completedAt.keys})
        id: _earliest(completedAt[id], other.completedAt[id]),
    },
    openedAt: openedAt.compareTo(other.openedAt) > 0
        ? openedAt
        : other.openedAt,
  );
  static String _earliest(String? a, String? b) {
    if (a == null) return b!;
    if (b == null) return a;
    return a.compareTo(b) <= 0 ? a : b;
  }
}

class ProgramService {
  ProgramService({SupabaseClient? client, SharedPreferencesAsync? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? SharedPreferencesAsync() {
    _account = _client.auth.currentUser?.id ?? 'guest';
  }
  final SupabaseClient _client;
  final SharedPreferencesAsync _storage;
  late final String _account;
  static final _queues = <String, Future<void>>{};
  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final previous = _queues[_account] ?? Future<void>.value();
    final release = Completer<void>();
    _queues[_account] = release.future;
    await previous;
    try {
      _checkAccount();
      return await action();
    } finally {
      release.complete();
      if (identical(_queues[_account], release.future)) {
        _queues.remove(_account);
      }
    }
  }

  bool syncPending = false;
  Object? lastSyncError;
  bool catalogOffline = false;
  LessonNotesService notesService() =>
      LessonNotesService(client: _client, storage: _storage);
  void ensureCurrentAccount() => _checkAccount();
  void _checkAccount() {
    if ((_client.auth.currentUser?.id ?? 'guest') != _account) {
      throw StateError('A conta mudou. Abra novamente a área de conteúdo.');
    }
  }

  String _key(String id) => 'pbh.learning.$_account.$id';
  Future<ProgramProgress> read(String id) async {
    _checkAccount();
    final raw = await _storage.getString(_key(id));
    if (raw != null) {
      return ProgramProgress.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    // Preferências antigas não identificavam conta: migram apenas para visitante.
    if (_account == 'guest') {
      return ProgramProgress(
        saved: await _storage.getBool('pbh.program.$id.saved') ?? false,
        started: await _storage.getBool('pbh.program.$id.started') ?? false,
      );
    }
    return const ProgramProgress();
  }

  Future<void> _write(String id, ProgramProgress progress) async {
    _checkAccount();
    await _storage.setString(_key(id), jsonEncode(progress.toJson()));
  }

  Future<Map<String, ProgramProgress>> loadAll(
    List<ProgramModel> programs,
  ) async {
    return _exclusive(() => _loadAll(programs));
  }

  Future<Map<String, ProgramProgress>> _loadAll(
    List<ProgramModel> programs,
  ) async {
    _checkAccount();
    syncPending = false;
    lastSyncError = null;
    final result = <String, ProgramProgress>{};
    for (final program in programs) {
      result[program.id] = await read(program.id);
    }
    if (_account == 'guest') return result;
    try {
      for (final id in result.keys.toList()) {
        if (result[id]!.pending) result[id] = await _sync(id, result[id]!);
      }
      final rows = await _client
          .from('content_progress')
          .select()
          .eq('user_id', _account)
          .timeout(const Duration(seconds: 8));
      _checkAccount();
      for (final row in rows) {
        final id = row['program_id'] as String;
        if (!result.containsKey(id)) continue;
        final remote = ProgramProgress.fromJson(row);
        var merged = result[id]!.merge(remote);
        if (merged.completedAt.entries.any(
          (e) => remote.completedAt[e.key] != e.value,
        )) {
          merged = await _sync(id, merged);
        }
        await _write(id, merged);
        result[id] = merged;
      }
    } catch (error) {
      _checkAccount();
      lastSyncError = error;
      syncPending = true;
    }
    return result;
  }

  Future<ProgramProgress> update(
    String id, {
    bool? saved,
    String? completedLesson,
    bool open = false,
  }) async {
    return _exclusive(
      () => _update(
        id,
        saved: saved,
        completedLesson: completedLesson,
        open: open,
      ),
    );
  }

  Future<ProgramProgress> _update(
    String id, {
    bool? saved,
    String? completedLesson,
    bool open = false,
  }) async {
    final previous = await read(id);
    final now = DateTime.now().toUtc().toIso8601String();
    final next = ProgramProgress(
      saved: saved ?? previous.saved,
      savedAt: saved != null ? now : previous.savedAt,
      started: previous.started || open || completedLesson != null,
      openedAt: open || completedLesson != null ? now : previous.openedAt,
      completed: {
        ...previous.completed,
        if (completedLesson != null) completedLesson,
      },
      completedAt: {
        ...previous.completedAt,
        if (completedLesson != null &&
            !previous.completed.contains(completedLesson))
          completedLesson: now,
      },
      pending: _account != 'guest',
    );
    await _write(id, next);
    if (_account == 'guest') return next;
    try {
      final synced = await _sync(id, next);
      syncPending = false;
      lastSyncError = null;
      return synced;
    } catch (error) {
      _checkAccount();
      lastSyncError = error;
      syncPending = true;
      return next;
    }
  }

  Future<ProgramProgress> _sync(String id, ProgramProgress progress) async {
    _checkAccount();
    final row = await _client
        .rpc(
          'merge_content_progress_v2',
          params: {
            'p_program_id': id,
            'p_saved': progress.saved,
            'p_saved_at': progress.savedAt.isEmpty ? null : progress.savedAt,
            'p_started': progress.started,
            'p_completed': progress.completed.toList(),
            'p_completed_at': progress.completedAt,
            'p_opened_at': progress.openedAt.isEmpty ? null : progress.openedAt,
          },
        )
        .timeout(const Duration(seconds: 8));
    _checkAccount();
    final merged = progress.merge(
      ProgramProgress.fromJson(Map<String, dynamic>.from(row as Map)),
    );
    await _write(id, merged);
    return merged;
  }

  Future<List<ProgramModel>> catalog({bool includeDrafts = false}) async {
    _checkAccount();
    final rows = await _client
        .from('content_programs')
        .select()
        .order('created_at')
        .timeout(const Duration(seconds: 8));
    _checkAccount();
    final remote = rows
        .where((r) => includeDrafts || r['published'] == true)
        .map((r) => ProgramModel.fromJson(r))
        .toList();
    if (!includeDrafts) {
      await _storage.setString(
        'pbh.learning.catalog',
        jsonEncode(remote.map((p) => p.toJson()).toList()),
      );
    }
    catalogOffline = false;
    return remote;
  }

  Future<List<ProgramModel>> availableCatalog() async {
    try {
      return await catalog();
    } catch (_) {
      _checkAccount();
      catalogOffline = true;
      final cache = await _storage.getString('pbh.learning.catalog');
      if (cache != null) {
        try {
          return (jsonDecode(cache) as List)
              .map(
                (p) =>
                    ProgramModel.fromJson(Map<String, dynamic>.from(p as Map)),
              )
              .toList();
        } catch (_) {
          /* Um cache inválido não impede o catálogo embarcado. */
        }
      }
      return programCatalog;
    }
  }

  static List<ProgramModel> recommend(
    List<ProgramModel> programs,
    Map<String, ProgramProgress> progress,
    Set<String> topics,
  ) {
    final indexed = programs.asMap().entries.toList();
    int score(ProgramModel p) {
      final state = progress[p.id] ?? const ProgramProgress();
      return (state.started && !state.isComplete(p) ? 100 : 0) +
          (topics.contains(p.topic) ? 10 : 0) +
          (state.saved ? 5 : 0) -
          (state.isComplete(p) ? 100 : 0);
    }

    indexed.sort((a, b) {
      final compared = score(b.value).compareTo(score(a.value));
      return compared != 0 ? compared : a.key.compareTo(b.key);
    });
    return indexed.map((e) => e.value).toList();
  }

  Future<Set<String>> topics() async {
    _checkAccount();
    return (await _storage.getStringList('pbh.learning.$_account.topics') ?? [])
        .toSet();
  }

  static ProgramModel? featured(List<ProgramModel> programs, {DateTime? now}) {
    final active =
        programs.where((p) => p.featuredAt(now ?? DateTime.now())).toList()
          ..sort((a, b) => b.featuredUntil!.compareTo(a.featuredUntil!));
    return active.isEmpty ? null : active.first;
  }

  Future<void> saveTopics(Set<String> topics) async {
    _checkAccount();
    await _storage.setStringList(
      'pbh.learning.$_account.topics',
      topics.toList(),
    );
  }
}
