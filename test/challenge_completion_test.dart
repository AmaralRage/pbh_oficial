import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/challenge_model.dart';
import 'package:pbh_oficial/models/challenge_journey.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/services/auth_service.dart';
import 'package:pbh_oficial/services/challenge_service.dart';

SupabaseClient createClient(
  String? email, {
  bool confirmed = true,
  List<Map<String, dynamic>>? catalog,
}) => SupabaseClient(
  'https://test.supabase.co',
  'public-test-key',
  authOptions: const AuthClientOptions(autoRefreshToken: false),
  httpClient: MockClient((request) async {
    Object response = <Object>[];
    if (request.url.path.endsWith('/token')) {
      response = {
        'access_token': 'test-token',
        'refresh_token': 'test-refresh',
        'token_type': 'bearer',
        'expires_in': 3600,
        'user': {
          'id': 'test-user',
          'email': email,
          'aud': 'authenticated',
          'app_metadata': {},
          'user_metadata': {},
          if (confirmed) 'email_confirmed_at': '2026-10-21T00:00:00Z',
          'created_at': '2026-10-21T00:00:00Z',
        },
      };
    } else if (request.url.path.endsWith('/challenge_catalog')) {
      response =
          catalog ??
          [
            {
              'id': 'test-challenge',
              'title': 'Test challenge',
              'description': 'Test',
              'total_days': 7,
              'level': 'iniciante',
              'icon_key': 'flag',
            },
          ];
    }
    return http.Response(
      jsonEncode(response),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }),
);

void main() {
  test(
    'confirmed leader receives both journey platinums; unconfirmed accounts do not',
    () async {
      final ids = {
        ...ChallengeJourney.original.challengeIds,
        ...ChallengeJourney.knowledge.challengeIds,
      };
      final catalog = [
        for (final id in ids)
          {
            'id': id,
            'title': id,
            'description': 'Test',
            'total_days': 7,
            'level': 'iniciante',
            'icon_key': 'book',
          },
      ];
      for (final confirmed in [true, false]) {
        final client = createClient(
          AuthService.adminEmail,
          confirmed: confirmed,
          catalog: catalog,
        );
        addTearDown(client.dispose);
        await client.auth.signInWithPassword(
          email: AuthService.adminEmail,
          password: 'test',
        );
        final challenges = await ChallengeService(
          client: client,
        ).fetchChallenges();
        final completed = challenges
            .where((c) => c.status == ChallengeStatus.completed)
            .map((c) => c.id)
            .toSet();
        expect(completed.length, confirmed ? 62 : 0);
        final awards = ProfileAchievement.earned(
          isAuthenticated: true,
          isProjectLeader: confirmed,
          streak: 0,
          completedChallenges: completed.length,
          totalChallenges: challenges.length,
          followers: 0,
          completedIds: completed,
        ).map((b) => b.id);
        if (confirmed) {
          expect(awards, containsAll(['platinum', 'knowledge_platinum']));
          expect(ChallengeJourney.knowledge.completedCount(completed), 5);
        } else {
          expect(awards, isNot(contains('knowledge_platinum')));
        }
      }
    },
  );
  test(
    'leader receives every challenge trophy at full progress before platinum',
    () async {
      final client = createClient(AuthService.adminEmail);
      addTearDown(client.dispose);
      await client.auth.signInWithPassword(
        email: AuthService.adminEmail,
        password: 'test',
      );
      final challenges = await ChallengeService(
        client: client,
      ).fetchChallenges();
      expect(challenges, isNotEmpty);
      for (final challenge in challenges) {
        expect(
          challenge.status,
          ChallengeStatus.completed,
          reason: challenge.id,
        );
        expect(challenge.currentDay, challenge.totalDays, reason: challenge.id);
        expect(challenge.progress, 1.0, reason: challenge.id);
      }
    },
  );

  test(
    'other accounts and visitors retain their actual challenge progress',
    () async {
      for (final email in <String?>['member@example.com', null]) {
        final client = createClient(email);
        addTearDown(client.dispose);
        if (email != null)
          await client.auth.signInWithPassword(email: email, password: 'test');
        final challenges = await ChallengeService(
          client: client,
        ).fetchChallenges();
        expect(challenges, isNotEmpty);
        expect(
          challenges.every(
            (challenge) => challenge.status == ChallengeStatus.notStarted,
          ),
          isTrue,
        );
        expect(
          challenges.every((challenge) => challenge.currentDay == 0),
          isTrue,
        );
      }
    },
  );
}
