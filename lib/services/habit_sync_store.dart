import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

typedef HabitWriter =
    Future<void> Function(
      String userId,
      String date,
      String habit,
      bool completed,
    );

/// Durable, account-scoped write-ahead queue. Replays are idempotent at the server.
class HabitSyncStore {
  HabitSyncStore(this.storage);
  final SharedPreferencesAsync storage;
  static final _tails = <String, Future<void>>{};
  static final _revisions = <String, int>{};
  int revision(String user, String date) => _revisions[_cache(user, date)] ?? 0;
  String _pending(String user) => 'pbh.habits.pending.$user.';
  String _cache(String user, String date) => 'pbh.habits.cache.$user.$date';

  Future<T> _serial<T>(String user, Future<T> Function() action) {
    final result = Completer<T>();
    final tail = (_tails[user] ?? Future<void>.value()).then((_) async {
      try {
        result.complete(await action());
      } catch (error, stack) {
        result.completeError(error, stack);
      }
    });
    _tails[user] = tail;
    unawaited(
      tail.then((_) {
        if (identical(_tails[user], tail)) _tails.remove(user);
      }),
    );
    return result.future;
  }

  Future<Set<String>?> cached(String user, String date) async =>
      (await storage.getStringList(_cache(user, date)))?.toSet();
  Future<void> cache(String user, String date, Set<String> values) =>
      storage.setStringList(_cache(user, date), values.toList());
  Future<int> pendingCount(String user) async => (await storage.getKeys())
      .where((key) => key.startsWith(_pending(user)))
      .length;

  Future<void> set(
    String user,
    String date,
    String habit,
    bool completed,
    HabitWriter writer,
    bool Function(Object) retryable,
  ) => _serial(user, () async {
    final previous = await cached(user, date);
    final values = {...?previous};
    if (completed) {
      values.add(habit);
    } else {
      values.remove(habit);
    }
    final key = '${_pending(user)}$date.$habit';
    _revisions[_cache(user, date)] = revision(user, date) + 1;
    await storage.setBool(key, completed);
    await cache(user, date, values);
    try {
      await writer(user, date, habit, completed);
      await storage.remove(key);
    } catch (error) {
      if (retryable(error)) return;
      if (previous == null) {
        await storage.remove(_cache(user, date));
      } else {
        await cache(user, date, previous);
      }
      await storage.remove(key);
      rethrow;
    } finally {
      _revisions[_cache(user, date)] = revision(user, date) + 1;
    }
  });

  Future<void> flush(
    String user,
    HabitWriter writer,
    bool Function(Object) retryable,
  ) => _serial(user, () async {
    final prefix = _pending(user);
    final keys =
        (await storage.getKeys())
            .where((key) => key.startsWith(prefix))
            .toList()
          ..sort();
    for (final key in keys) {
      final rest = key.substring(prefix.length);
      final split = rest.lastIndexOf('.');
      if (split < 0) continue;
      final value = await storage.getBool(key);
      if (value == null) continue;
      try {
        await writer(
          user,
          rest.substring(0, split),
          rest.substring(split + 1),
          value,
        );
        final date = rest.substring(0, split);
        _revisions[_cache(user, date)] = revision(user, date) + 1;
        await storage.remove(key);
      } catch (error) {
        if (retryable(error)) return;
        rethrow;
      }
    }
  });

  /// Pending local choices win over a server read that started before the write.
  Future<Set<String>> overlay(
    String user,
    String date,
    Set<String> server, {
    int? expectedRevision,
  }) => _serial(user, () async {
    if (expectedRevision != null && expectedRevision != revision(user, date))
      return await cached(user, date) ?? server;
    final result = {...server};
    final prefix = '${_pending(user)}$date.';
    for (final key in (await storage.getKeys()).where(
      (key) => key.startsWith(prefix),
    )) {
      final value = await storage.getBool(key);
      if (value == true) {
        result.add(key.substring(prefix.length));
      }
      if (value == false) {
        result.remove(key.substring(prefix.length));
      }
    }
    await cache(user, date, result);
    return result;
  });
}
