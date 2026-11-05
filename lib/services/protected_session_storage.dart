import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

LocalStorage? protectedSessionStorage(String url) {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  final key = 'sb-${Uri.parse(url).host.split('.').first}-auth-token';
  const secure = FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: false),
  );
  final legacy = SharedPreferencesLocalStorage(persistSessionKey: key);
  return ProtectedSessionStorage(
    initializeLegacy: legacy.initialize,
    readLegacy: legacy.accessToken,
    removeLegacy: legacy.removePersistedSession,
    readSecure: () => secure.read(key: key),
    writeSecure: (value) => secure.write(key: key, value: value),
    removeSecure: () => secure.delete(key: key),
  );
}

class ProtectedSessionStorage extends LocalStorage {
  const ProtectedSessionStorage({
    required this.initializeLegacy,
    required this.readLegacy,
    required this.removeLegacy,
    required this.readSecure,
    required this.writeSecure,
    required this.removeSecure,
  });
  final Future<void> Function() initializeLegacy, removeLegacy, removeSecure;
  final Future<String?> Function() readLegacy, readSecure;
  final Future<void> Function(String) writeSecure;
  @override
  Future<void> initialize() async {
    await initializeLegacy();
    final current = await readSecure();
    if (current != null) {
      await removeLegacy();
      return;
    }
    final old = await readLegacy();
    if (old == null) return;
    await writeSecure(old);
    if (await readSecure() != old)
      throw StateError('Não foi possível proteger a sessão.');
    await removeLegacy();
  }

  @override
  Future<bool> hasAccessToken() async => await readSecure() != null;
  @override
  Future<String?> accessToken() => readSecure();
  @override
  Future<void> persistSession(String value) => writeSecure(value);
  @override
  Future<void> removePersistedSession() async {
    await removeSecure();
    await removeLegacy();
  }
}
