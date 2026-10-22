import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/public_member_profile.dart';
import 'package:pbh_oficial/services/public_member_profile_service.dart';

void main() {
  const id = '00000000-0000-0000-0000-000000000001';
  Map<String, dynamic> profile({bool shared = true, bool own = false}) => {
    'id': id,
    'name': 'Membro',
    'bio': 'Minha jornada',
    'founder': false,
    'is_own': own,
    'progress_shared': shared,
    'style': {
      'profile_theme': 'nova',
      'featured': ['daily_reading', 'platinum'],
      'title': 'platinum',
    },
    'progress': {
      'completed': 1,
      'total': 57,
      'completed_ids': ['daily_reading'],
      'manual_awards': [],
      'followers': 0,
      'streak': 0,
    },
  };
  test(
    'public profile shows earned highlights without awarding unearned platinum',
    () {
      final member = PublicMemberProfile.fromMap(profile());
      expect(member.style.profileTheme, 'nova');
      expect(member.hasProgress, isTrue);
      expect(member.style.title, 'member');
      expect(member.style.highlights(member.earned).map((b) => b.id), [
        'daily_reading',
      ]);
      expect(member.earned.any((b) => b.id == 'platinum'), isFalse);
    },
  );
  test(
    'hidden progress never becomes zeros or badges even with a stale payload',
    () {
      final member = PublicMemberProfile.fromMap(profile(shared: false));
      expect(member.hasProgress, isFalse);
      expect(member.completed, isNull);
      expect(member.followers, isNull);
      expect(member.earned, isEmpty);
      expect(member.style.featured, isEmpty);
      expect(member.style.title, 'member');
      expect(
        PublicMemberProfile.fromMap(
          profile(shared: false, own: true),
        ).hasProgress,
        isTrue,
      );
    },
  );
  test(
    'missing, private and blocked profiles use the same unavailable response',
    () async {
      var requests = 0;
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url.path, '/rest/v1/rpc/community_member_profile');
          expect(jsonDecode(request.body), {'p_user_id': id});
          return http.Response(
            'null',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final service = PublicMemberProfileService(client: client);
      expect(await service.fetch('example-member'), isNull);
      expect(requests, 0);
      expect(await service.fetch(id), isNull);
      expect(requests, 1);
    },
  );
  test(
    'network failure is surfaced and not mistaken for a private profile',
    () async {
      final client = SupabaseClient(
        'https://test.supabase.co',
        'public-key',
        httpClient: MockClient(
          (request) async => throw http.ClientException('offline'),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        PublicMemberProfileService(client: client).fetch(id),
        throwsA(isA<http.ClientException>()),
      );
    },
  );
}
