import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/announcement_service.dart';

void main() {
  test(
    'mobile push failure is reported even when the web delivery succeeds',
    () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient(
          (request) async => http.Response(
            jsonEncode({'sent': 1, 'warning': 'FCM configuration pending'}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        AnnouncementService(client: client).sendPush(announcementId: 'test'),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'FCM configuration pending',
          ),
        ),
      );
    },
  );
  test(
    'scheduling uses UTC and cancellation addresses only the selected schedule',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response(
            'null',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final service = AnnouncementService(client: client);
      final when = DateTime.now().add(const Duration(days: 1));
      await service.schedule(
        title: ' Aviso ',
        message: ' Mensagem ',
        audience: 'members',
        soundEnabled: false,
        scheduledAt: when,
      );
      final body = jsonDecode(requests.first.body) as Map;
      expect(requests.first.url.path, endsWith('/rpc/schedule_announcement'));
      expect(body['p_scheduled_at'], when.toUtc().toIso8601String());
      expect(body['p_title'], 'Aviso');
      expect(body['p_audience'], 'members');
      expect(body['p_sound_enabled'], false);
      await service.cancelSchedule('schedule-id');
      expect(jsonDecode(requests.last.body), {'p_id': 'schedule-id'});
      expect(
        requests.last.url.path,
        endsWith('/rpc/cancel_announcement_schedule'),
      );
      await expectLater(
        service.schedule(
          title: 'Test',
          message: 'Body',
          audience: 'all',
          soundEnabled: true,
          scheduledAt: DateTime.now().subtract(const Duration(minutes: 1)),
        ),
        throwsArgumentError,
      );
      expect(requests.length, 2);
    },
  );
}
