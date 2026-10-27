import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/lesson_notes_service.dart';

class DeviceStorage extends SharedPreferencesAsync {
  final data = <String, Object>{};
  @override
  Future<String?> getString(String key) async => data[key] as String?;
  @override
  Future<int?> getInt(String key) async => data[key] as int?;
  @override
  Future<bool?> getBool(String key) async => data[key] as bool?;
  @override
  Future<void> setString(String key, String value) async {
    data[key] = value;
  }

  @override
  Future<void> setInt(String key, int value) async {
    data[key] = value;
  }

  @override
  Future<void> setBool(String key, bool value) async {
    data[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  test(
    'notes synchronize across devices, retain offline edits and expose conflicts',
    () async {
      final jwt =
          'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature';
      Map<String, dynamic>? note;
      var online = true;
      final client = SupabaseClient(
        'https://fixture.supabase.co',
        'public',
        httpClient: MockClient((request) async {
          Object? result;
          if (request.url.path.startsWith('/auth/')) {
            result = {
              'access_token': jwt,
              'refresh_token': 'refresh',
              'token_type': 'bearer',
              'expires_in': 3600,
              'user': {
                'id': 'ad270000-0000-4000-8000-000000000001',
                'aud': 'authenticated',
                'email': 'member@example.invalid',
                'created_at': '2026-01-01T00:00:00Z',
                'app_metadata': {},
                'user_metadata': {},
              },
            };
          } else {
            if (!online) throw http.ClientException('offline');
            if (request.url.path.contains('/rpc/')) {
              final body = jsonDecode(request.body);
              if (body['p_revision'] != (note?['revision'] ?? 0)) {
                result = {'conflict': true, 'note': note};
              } else {
                note = {
                  'content': body['p_content'],
                  'revision': (note?['revision'] as int? ?? 0) + 1,
                };
                result = {'conflict': false, 'note': note};
              }
            } else {
              result =
                  request.headers['Accept'] ==
                          'application/vnd.pgrst.object+json' ||
                      request.headers['accept'] ==
                          'application/vnd.pgrst.object+json'
                  ? note
                  : note == null
                  ? []
                  : [note];
            }
          }
          return http.Response(
            jsonEncode(result),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: 'member@example.invalid',
        password: 'test',
      );
      final a = LessonNotesService(client: client, storage: DeviceStorage());
      final b = LessonNotesService(client: client, storage: DeviceStorage());
      await a.save('p', 'l', 'first');
      expect(a.syncPending, isFalse, reason: a.lastSyncError.toString());
      expect(await b.load('p', 'l'), 'first');
      await a.save('p', 'l', 'new from A');
      await b.save('p', 'l', 'draft from B');
      expect(b.conflict, isTrue);
      expect(note!['content'], 'new from A');
      expect(await b.useRemote('p', 'l'), 'new from A');
      online = false;
      await b.save('p', 'l', 'offline');
      expect(b.syncPending, isTrue);
      expect(await b.load('p', 'l'), 'offline');
      online = true;
      expect(await b.load('p', 'l'), 'offline');
      expect(b.syncPending, isFalse);
      final c = LessonNotesService(client: client, storage: DeviceStorage());
      expect(await c.load('p', 'l'), 'offline');
    },
  );
}
