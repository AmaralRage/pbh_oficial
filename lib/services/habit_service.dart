import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HabitService {
  HabitService({SupabaseClient? client, SharedPreferencesAsync? storage})
      : _client = client ?? Supabase.instance.client,
        _storage = storage ?? SharedPreferencesAsync();

  final SupabaseClient _client;
  final SharedPreferencesAsync _storage;
  static const habitKeys = ['train', 'read', 'digital_fast', 'meditate', 'sleep_early'];

  String get _userKey => _client.auth.currentUser?.id ?? 'guest';
  String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<Set<String>> completedOn(DateTime date) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      final values = await Future.wait(habitKeys.map((key) => _storage.getBool('pbh.habit.$_userKey.${_dateKey(date)}.$key')));
      return {for (var i = 0; i < habitKeys.length; i++) if (values[i] == true) habitKeys[i]};
    }
    final rows = await _client.from('habit_completions').select('habit_key').eq('user_id', userId).eq('completed_on', _dateKey(date));
    return rows.map((row) => row['habit_key'] as String).toSet();
  }

  Future<void> setCompleted(String habitKey, DateTime date, bool complete) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await _storage.setBool('pbh.habit.$_userKey.${_dateKey(date)}.$habitKey', complete);
      return;
    }
    if (complete) {
      await _client.from('habit_completions').insert({'user_id': userId, 'habit_key': habitKey, 'completed_on': _dateKey(date)});
    } else {
      await _client.from('habit_completions').delete().eq('user_id', userId).eq('habit_key', habitKey).eq('completed_on', _dateKey(date));
    }
  }

  Future<int> streak() async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 370));
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      var count = 0;
      var cursor = DateTime(today.year, today.month, today.day);
      for (var offset = 0; offset < 371; offset++) {
        if ((await completedOn(cursor)).isEmpty) break;
        count++;
        cursor = cursor.subtract(const Duration(days: 1));
      }
      return count;
    }
    final rows = await _client.from('habit_completions').select('completed_on').eq('user_id', userId).gte('completed_on', _dateKey(start)).lte('completed_on', _dateKey(today));
    final dates = rows.map((row) => row['completed_on'] as String).toSet();
    var count = 0;
    var cursor = DateTime(today.year, today.month, today.day);
    if (!dates.contains(_dateKey(cursor))) cursor = cursor.subtract(const Duration(days: 1));
    while (dates.contains(_dateKey(cursor))) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  Future<List<int>> weekCounts(DateTime today) async {
    final monday = DateTime(today.year, today.month, today.day).subtract(Duration(days: today.weekday - 1));
    final values = await Future.wait(List.generate(7, (index) => completedOn(monday.add(Duration(days: index)))));
    return values.map((set) => set.length).toList();
  }
}
