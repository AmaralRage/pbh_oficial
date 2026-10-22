import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'habit_sync_store.dart';

class HabitService {
  HabitService({SupabaseClient? client, SharedPreferencesAsync? storage})
    : _client = client ?? Supabase.instance.client,
      _storage = storage ?? SharedPreferencesAsync();

  final SupabaseClient _client;
  final SharedPreferencesAsync _storage;
  late final _sync = HabitSyncStore(_storage);
  bool isUsingCachedData = false;
  void resetReadStatus() => isUsingCachedData = false;
  bool _retryable(Object error) =>
      error is http.ClientException ||
      error is TimeoutException ||
      (error is PostgrestException &&
          ['500', '502', '503', '504'].contains(error.code));
  Future<int> pendingChanges() async => _client.auth.currentUser == null
      ? 0
      : _sync.pendingCount(_client.auth.currentUser!.id);
  Future<void> syncPending() async {
    final user = _client.auth.currentUser?.id;
    if (user != null) await _sync.flush(user, _write, _retryable);
  }

  Future<void> _write(
    String user,
    String date,
    String habit,
    bool completed,
  ) async {
    if (_client.auth.currentUser?.id != user)
      throw StateError('A conta mudou. Abra novamente sua rotina.');
    if (!habitKeys.contains(habit) ||
        DateTime.tryParse(date) == null ||
        date.compareTo(_dateKey(DateTime.now())) > 0)
      throw ArgumentError('Marcação de hábito inválida.');
    if (completed) {
      await _client
          .from('habit_completions')
          .upsert(
            {'user_id': user, 'habit_key': habit, 'completed_on': date},
            onConflict: 'user_id,habit_key,completed_on',
            ignoreDuplicates: true,
          )
          .timeout(const Duration(seconds: 10));
    } else {
      await _client
          .from('habit_completions')
          .delete()
          .eq('user_id', user)
          .eq('habit_key', habit)
          .eq('completed_on', date)
          .timeout(const Duration(seconds: 10));
    }
  }

  static const habitKeys = [
    'train',
    'read',
    'digital_fast',
    'meditate',
    'sleep_early',
  ];

  String get _userKey => _client.auth.currentUser?.id ?? 'guest';
  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Set<String>> selectedHabitKeys() async {
    final saved = await _storage.getStringList('pbh.habits.selected.$_userKey');
    if (saved == null) return habitKeys.toSet();
    final selected = saved.where(habitKeys.contains).toSet();
    return selected.isEmpty ? habitKeys.toSet() : selected;
  }

  Future<void> saveSelectedHabitKeys(Set<String> keys) async {
    final selected = keys.where(habitKeys.contains).toSet();
    if (selected.isEmpty)
      throw ArgumentError('Escolha pelo menos um hábito para sua rotina.');
    await _storage.setStringList(
      'pbh.habits.selected.$_userKey',
      selected.toList(),
    );
  }

  Future<Set<String>> completedOn(DateTime date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      final values = await Future.wait(
        habitKeys.map(
          (key) =>
              _storage.getBool('pbh.habit.$_userKey.${_dateKey(date)}.$key'),
        ),
      );
      return {
        for (var i = 0; i < habitKeys.length; i++)
          if (values[i] == true) habitKeys[i],
      };
    }
    final readRevision = _sync.revision(userId, _dateKey(date));
    try {
      final rows = await _client
          .from('habit_completions')
          .select('habit_key')
          .eq('user_id', userId)
          .eq('completed_on', _dateKey(date))
          .timeout(const Duration(seconds: 10));
      return await _sync.overlay(
        userId,
        _dateKey(date),
        rows.map((row) => row['habit_key'] as String).toSet(),
        expectedRevision: readRevision,
      );
    } catch (error) {
      if (!_retryable(error)) rethrow;
      final cached = await _sync.cached(userId, _dateKey(date));
      if (cached == null) rethrow;
      isUsingCachedData = true;
      return cached;
    }
  }

  Future<void> setCompleted(
    String habitKey,
    DateTime date,
    bool complete,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await _storage.setBool(
        'pbh.habit.$_userKey.${_dateKey(date)}.$habitKey',
        complete,
      );
      return;
    }
    await _sync.set(
      userId,
      _dateKey(date),
      habitKey,
      complete,
      _write,
      _retryable,
    );
  }

  /// Moves visitor habit history into the signed-in account without replacing
  /// records that already exist there. Local keys are removed only after the
  /// server confirms the batch write.
  Future<int> migrateGuestHistory() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;

    const guestPrefix = 'pbh.habit.guest.';
    final guestKeys = (await _storage.getKeys())
        .where((key) => key.startsWith(guestPrefix))
        .toList();
    final rows = <Map<String, dynamic>>[];
    final migratedKeys = <String>[];
    for (final key in guestKeys) {
      final remainder = key.substring(guestPrefix.length);
      final separator = remainder.lastIndexOf('.');
      if (separator <= 0) continue;
      final date = remainder.substring(0, separator);
      final habitKey = remainder.substring(separator + 1);
      if (!habitKeys.contains(habitKey) ||
          !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date))
        continue;
      if (DateTime.tryParse(date) == null ||
          date.compareTo(_dateKey(DateTime.now())) > 0)
        continue;
      if (await _storage.getBool(key) != true) continue;
      rows.add({
        'user_id': userId,
        'habit_key': habitKey,
        'completed_on': date,
      });
      migratedKeys.add(key);
    }
    if (rows.isEmpty) return 0;

    await _client
        .from('habit_completions')
        .upsert(
          rows,
          onConflict: 'user_id,habit_key,completed_on',
          ignoreDuplicates: true,
        );
    await Future.wait(migratedKeys.map(_storage.remove));
    return migratedKeys.length;
  }

  Future<int> streak({Set<String>? habitKeysForStreak}) async {
    final user = _client.auth.currentUser?.id;
    if (user == null) return 0;
    final selected = (habitKeysForStreak ?? await selectedHabitKeys()).toList()
      ..sort();
    final key = 'pbh.habits.streak.$user.${selected.join(',')}';
    try {
      final count = await _onlineStreak(
        habitKeysForStreak: selected.toSet(),
      ).timeout(const Duration(seconds: 12));
      await _storage.setInt(key, count);
      return count;
    } catch (error) {
      if (!_retryable(error)) rethrow;
      final cached = await _storage.getInt(key);
      if (cached == null) rethrow;
      isUsingCachedData = true;
      return cached;
    }
  }

  Future<int> _onlineStreak({Set<String>? habitKeysForStreak}) async {
    final today = DateTime.now();
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    final selected = habitKeysForStreak ?? await selectedHabitKeys();
    if (selected.isEmpty) return 0;
    final todayStart = DateTime(today.year, today.month, today.day);
    final dates = <String>{};
    var cursor = todayStart;
    var count = 0;
    var offset = 0;
    var checkedToday = false;
    while (true) {
      final rows = await _client
          .from('habit_completions')
          .select('completed_on')
          .eq('user_id', userId)
          .inFilter('habit_key', selected.toList())
          .lte('completed_on', _dateKey(today))
          .order('completed_on', ascending: false)
          .range(offset, offset + 999);
      if (rows.isEmpty) break;
      dates.addAll(rows.map((row) => row['completed_on'] as String));
      final earliest = rows.last['completed_on'] as String;

      if (!checkedToday && dates.contains(_dateKey(todayStart))) {
        checkedToday = true;
      } else if (!checkedToday &&
          (earliest.compareTo(_dateKey(todayStart)) < 0 ||
              rows.length < 1000)) {
        cursor = cursor.subtract(const Duration(days: 1));
        checkedToday = true;
      }
      while (dates.contains(_dateKey(cursor))) {
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      if (earliest.compareTo(_dateKey(cursor)) < 0 || rows.length < 1000) break;
      offset += rows.length;
    }
    return count;
  }

  Future<List<int>> weekCounts(
    DateTime today, {
    Set<String>? selectedHabits,
  }) async {
    final monday = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final user = _client.auth.currentUser?.id;
    if (user != null) {
      final revisions = [
        for (var i = 0; i < 7; i++)
          _sync.revision(user, _dateKey(monday.add(Duration(days: i)))),
      ];
      try {
        final rows = await _client
            .from('habit_completions')
            .select('habit_key,completed_on')
            .eq('user_id', user)
            .gte('completed_on', _dateKey(monday))
            .lte('completed_on', _dateKey(monday.add(const Duration(days: 6))))
            .timeout(const Duration(seconds: 10));
        final values = <Set<String>>[];
        for (var i = 0; i < 7; i++) {
          final date = _dateKey(monday.add(Duration(days: i)));
          values.add(
            await _sync.overlay(
              user,
              date,
              rows
                  .where((r) => r['completed_on'] == date)
                  .map((r) => r['habit_key'] as String)
                  .toSet(),
              expectedRevision: revisions[i],
            ),
          );
        }
        return values
            .map(
              (set) => selectedHabits == null
                  ? set.length
                  : set.intersection(selectedHabits).length,
            )
            .toList();
      } catch (error) {
        if (!_retryable(error)) rethrow;
        final values = <Set<String>>[];
        for (var i = 0; i < 7; i++) {
          final cached = await _sync.cached(
            user,
            _dateKey(monday.add(Duration(days: i))),
          );
          if (cached == null) rethrow;
          values.add(cached);
        }
        isUsingCachedData = true;
        return values
            .map(
              (set) => selectedHabits == null
                  ? set.length
                  : set.intersection(selectedHabits).length,
            )
            .toList();
      }
    }
    final values = await Future.wait(
      List.generate(
        7,
        (index) => completedOn(monday.add(Duration(days: index))),
      ),
    );
    return values
        .map(
          (set) => selectedHabits == null
              ? set.length
              : set.intersection(selectedHabits).length,
        )
        .toList();
  }
}
