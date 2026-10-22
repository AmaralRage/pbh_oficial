import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/services/community_service.dart';
import 'package:pbh_oficial/services/minute_clock.dart';

void main() {
  test(
    'comments request bounded pages with a stable newest-first order',
    () async {
      final requests = <Uri>[];
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient((request) async {
          requests.add(request.url);
          return http.Response(
            '[]',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = CommunityService(client: client);
      await service.fetchComments('post', offset: 30);
      await service.fetchComments('sample', isSample: true);
      expect(requests[0].queryParameters['offset'], '30');
      expect(requests[0].queryParameters['limit'], '30');
      expect(
        requests[0].queryParameters['order']!.replaceAll('.nullslast', ''),
        'created_at.desc,id.desc',
      );
      expect(requests[1].path, contains('community_sample_comment_feed'));
      expect(requests[1].queryParameters['sample_post_key'], 'eq.sample');
      await client.dispose();
    },
  );
  testWidgets('the shared clock updates all listeners and stops when unused', (
    tester,
  ) async {
    final clock = MinuteClock();
    var first = 0, second = 0;
    void a() => first++;
    void b() => second++;
    clock.addListener(a);
    clock.addListener(b);
    await tester.pump(const Duration(minutes: 1));
    expect([first, second], [1, 1]);
    clock.removeListener(a);
    await tester.pump(const Duration(minutes: 1));
    expect([first, second], [1, 2]);
    clock.removeListener(b);
    await tester.pump(const Duration(minutes: 2));
    expect([first, second], [1, 2]);
    clock.dispose();
  });
}
