import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/services/protected_session_storage.dart';

void main() {
  test(
    'migration removes plaintext only after secure readback, preserves active session',
    () async {
      String? old = 'session', secure;
      final store = ProtectedSessionStorage(
        initializeLegacy: () async {},
        readLegacy: () async => old,
        removeLegacy: () async {
          old = null;
        },
        readSecure: () async => secure,
        writeSecure: (value) async {
          secure = value;
        },
        removeSecure: () async {
          secure = null;
        },
      );
      await store.initialize();
      expect(old, isNull);
      expect(await store.accessToken(), 'session');
      await store.persistSession('new-session');
      expect(await store.accessToken(), 'new-session');
      await store.removePersistedSession();
      expect(await store.hasAccessToken(), false);
    },
  );
  test('failed secure write never deletes original session', () async {
    String? old = 'session';
    final store = ProtectedSessionStorage(
      initializeLegacy: () async {},
      readLegacy: () async => old,
      removeLegacy: () async {
        old = null;
      },
      readSecure: () async => null,
      writeSecure: (_) async {
        throw StateError('locked');
      },
      removeSecure: () async {},
    );
    await expectLater(store.initialize(), throwsStateError);
    expect(old, 'session');
  });
  test('existing protected session wins over stale plaintext', () async {
    String? old = 'stale';
    final store = ProtectedSessionStorage(
      initializeLegacy: () async {},
      readLegacy: () async => old,
      removeLegacy: () async {
        old = null;
      },
      readSecure: () async => 'current',
      writeSecure: (_) async {
        fail('must not overwrite');
      },
      removeSecure: () async {},
    );
    await store.initialize();
    expect(old, isNull);
    expect(await store.accessToken(), 'current');
  });
}
