import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pbh_oficial/services/habit_sync_store.dart';

class Offline implements Exception {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferencesAsync storage;
  late HabitSyncStore store;
  bool retryable(Object error) => error is Offline;
  Future<void> offline(String u, String d, String h, bool c) async =>
      throw Offline();
  const date = '2026-10-22';
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    storage = SharedPreferencesAsync();
    store = HabitSyncStore(storage);
  });
  test(
    'offline choices survive recreation and flush only the latest intent',
    () async {
      await store.cache('a', date, {'read'});
      await store.set('a', date, 'train', true, offline, retryable);
      await store.set('a', date, 'train', false, offline, retryable);
      final recreated = HabitSyncStore(storage);
      expect(await recreated.pendingCount('a'), 1);
      expect(await recreated.cached('a', date), {'read'});
      final sent = <bool>[];
      await recreated.flush('a', (u, d, h, c) async {
        sent.add(c);
      }, retryable);
      expect(sent, [false]);
      expect(await recreated.pendingCount('a'), 0);
    },
  );
  test('one account cannot flush another account pending changes', () async {
    await store.set('a', date, 'read', true, offline, retryable);
    await store.flush(
      'b',
      (u, d, h, c) async => fail('must not upload another account'),
      retryable,
    );
    expect(await store.pendingCount('a'), 1);
    expect(await store.cached('b', date), isNull);
  });
  test(
    'permission failures roll back cache and are not treated as offline success',
    () async {
      await store.cache('a', date, {'read'});
      await expectLater(
        store.set(
          'a',
          date,
          'train',
          true,
          (u, d, h, c) async => throw StateError('denied'),
          retryable,
        ),
        throwsStateError,
      );
      expect(await store.cached('a', date), {'read'});
      expect(await store.pendingCount('a'), 0);
    },
  );
  test('a late server read cannot erase an acknowledged local write', () async {
    final revision = store.revision('a', date);
    await store.set('a', date, 'train', true, (u, d, h, c) async {}, retryable);
    final merged = await store.overlay(
      'a',
      date,
      {},
      expectedRevision: revision,
    );
    expect(merged, {'train'});
  });
  test(
    'a read started while a write was in flight cannot replace its result',
    () async {
      final gate = Completer<void>();
      final started = Completer<void>();
      final write = store.set('a', date, 'train', true, (u, d, h, c) async {
        started.complete();
        await gate.future;
      }, retryable);
      await started.future;
      final revision = store.revision('a', date);
      final read = store.overlay('a', date, {}, expectedRevision: revision);
      gate.complete();
      await write;
      expect(await read, {'train'});
    },
  );
}
