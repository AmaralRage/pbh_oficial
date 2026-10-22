import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/habit_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'weekly reads use one request; offline writes replay after service recreation',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      var online = true;
      final requests = <http.Request>[];
      final today = DateTime.now();
      final monday = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: today.weekday - 1));
      String date(DateTime day) =>
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final jwt =
          'e30.${base64Url.encode(utf8.encode(jsonEncode({'exp': 4102444800}))).replaceAll('=', '')}.signature';
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient((request) async {
          if (request.url.path.startsWith('/auth/'))
            return http.Response(
              jsonEncode({
                'access_token': jwt,
                'refresh_token': 'refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': '00000000-0000-0000-0000-000000000001',
                  'aud': 'authenticated',
                  'email': 'member@example.com',
                  'created_at': '2026-01-01T00:00:00Z',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              }),
              200,
              request: request,
              headers: {'content-type': 'application/json'},
            );
          requests.add(request);
          if (!online) throw http.ClientException('offline');
          return http.Response(
            request.method == 'GET'
                ? jsonEncode([
                    {'habit_key': 'read', 'completed_on': date(monday)},
                  ])
                : '',
            request.method == 'GET' ? 200 : 201,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      await client.auth.signInWithPassword(
        email: 'member@example.com',
        password: 'test-password',
      );
      final service = HabitService(client: client);
      final counts = await service.weekCounts(today);
      expect(counts, [1, 0, 0, 0, 0, 0, 0]);
      expect(requests.length, 1);
      online = false;
      await service.setCompleted('train', today, true);
      expect(await service.pendingChanges(), 1);
      expect(await service.completedOn(today), contains('train'));
      expect(service.isUsingCachedData, true);
      final recreated = HabitService(client: client);
      online = true;
      await recreated.syncPending();
      expect(await recreated.pendingChanges(), 0);
      expect(jsonDecode(requests.last.body)['habit_key'], 'train');
      expect(
        requests.last.headers['Prefer'],
        contains('resolution=ignore-duplicates'),
      );
      await client.dispose();
    },
  );
}
