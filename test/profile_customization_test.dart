import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/models/profile_achievement.dart';
import 'package:pbh_oficial/services/profile_customization_service.dart';

class TestCustomization extends ProfileCustomizationService {
  TestCustomization(SupabaseClient client) : super(client: client);
  @override
  Future<ProfileUnlocks> unlocks() async =>
      const ProfileUnlocks(1, [ProfileAchievement.challenges50]);
}

void main() {
  test(
    'effects persist independently of cover uploads and founder choices are restricted',
    () {
      final draft = const ProfileStyle(
        frameEffect: 'sparks',
        coverEffect: 'aurora',
      );
      final restored = ProfileStyle.fromMetadata({
        'profile_style': draft.toMap(),
        'cover_url': 'https://example.com/my-cover.png',
      }).validated(founder: false, completed: 0, earned: []);
      expect(restored.frameEffect, 'sparks');
      expect(restored.coverEffect, 'aurora');
      final blocked = const ProfileStyle(
        frameEffect: 'crown',
        coverEffect: 'legacy',
      ).validated(founder: false, completed: 100, earned: []);
      expect(blocked.frameEffect, 'orbit');
      expect(blocked.coverEffect, 'shimmer');
      final founder = ProfileStyle.fromMetadata(
        {},
        founder: true,
      ).validated(founder: true, completed: 0, earned: []);
      expect(founder.frameEffect, 'crown');
      expect(founder.coverEffect, 'legacy');
      expect(
        ProfileStyle.frames.firstWhere((o) => o.id == 'founder').color,
        isNot(ProfileStyle.frames.firstWhere((o) => o.id == 'gold').color),
      );
      final still = draft.copyWith(frameEffect: 'none', coverEffect: 'none');
      expect(
        ProfileStyle.fromMetadata({'profile_style': still.toMap()}).coverEffect,
        'none',
      );
    },
  );
  test(
    'unearned styles and founder identity cannot be selected by a member',
    () {
      final style =
          ProfileStyle.fromMetadata({
            'profile_style': {
              'frame': 'founder',
              'cover': 'founder',
              'title': 'founder',
              'featured': ['platinum', 'challenges', 'challenges'],
            },
          }, founder: false).validated(
            founder: false,
            completed: 1,
            earned: [ProfileAchievement.challenges50],
          );
      expect(style.frame, 'orange');
      expect(style.cover, 'ember');
      expect(style.title, 'member');
      expect(style.featured, ['challenges']);
      expect(
        style.highlights([ProfileAchievement.challenges50]).single.id,
        'challenges',
      );
      expect(
        const ProfileStyle(
          frame: 'gold',
        ).validated(founder: false, completed: 29, earned: []).frame,
        'orange',
      );
      expect(
        const ProfileStyle(
          frame: 'gold',
        ).validated(founder: false, completed: 30, earned: []).frame,
        'gold',
      );
      expect(
        const ProfileStyle(
          frame: 'platinum',
        ).validated(founder: false, completed: 100, earned: []).frame,
        'orange',
      );
    },
  );
  test(
    'founder defaults are exclusive; showcases preserve selection order and allow empty',
    () {
      final founder = ProfileStyle.fromMetadata(
        {},
        founder: true,
      ).validated(founder: true, completed: 0, earned: []);
      expect(founder.frame, 'founder');
      expect(founder.cover, 'founder');
      expect(founder.titleLabel([]), 'Fundador do PBH');
      final badges = [
        ProfileAchievement.challenges50,
        ProfileAchievement.platinum,
        ProfileAchievement.dedication2000,
        ProfileAchievement.supremeSeals.first,
      ];
      expect(const ProfileStyle().highlights(badges).length, 3);
      final picked = const ProfileStyle(
        featured: ['streak', 'platinum', 'streak', 'challenges'],
      );
      expect(picked.highlights(badges).map((b) => b.id), [
        'streak',
        'platinum',
        'challenges',
      ]);
      expect(const ProfileStyle(featured: []).highlights(badges), isEmpty);
      expect(
        ProfileStyle.fromMetadata({'profile_style': 'invalid'}).frame,
        'orange',
      );
    },
  );
  test('photo validation rejects unsupported content and oversized files', () {
    expect(
      () => ProfileCustomizationService.imageType(
        Uint8List.fromList(utf8.encode('<svg/>')),
      ),
      throwsArgumentError,
    );
    expect(
      () =>
          ProfileCustomizationService.imageType(Uint8List(5 * 1024 * 1024 + 1)),
      throwsArgumentError,
    );
    expect(
      ProfileCustomizationService.imageType(
        Uint8List.fromList([255, 216, 255]),
      ),
      'jpeg',
    );
  });
  for (final cover in [false, true]) {
    for (final fail in [false, true]) {
      test(
        'upload then save metadata; failed save cleans only the new upload (fail=$fail, cover=$cover)',
        () async {
          final requests = <http.Request>[];
          final user = {
            'id': 'member-id',
            'email': 'member@example.com',
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {
              'avatar_url':
                  'https://test.supabase.co/storage/v1/object/public/profile-avatars/member-id/old.png',
              'cover_url':
                  'https://test.supabase.co/storage/v1/object/public/profile-covers/member-id/old.png',
            },
            'created_at': '2026-10-21T00:00:00Z',
          };
          final client = SupabaseClient(
            'https://test.supabase.co',
            'test-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
            httpClient: MockClient((request) async {
              requests.add(request);
              Object body = {};
              var status = 200;
              if (request.url.path.endsWith('/token')) {
                body = {
                  'access_token': 'test-token',
                  'refresh_token': 'refresh',
                  'token_type': 'bearer',
                  'expires_in': 3600,
                  'user': user,
                };
              } else if (request.url.path.endsWith('/user')) {
                if (fail) {
                  status = 500;
                  body = {'msg': 'save failed'};
                } else {
                  body = {
                    ...user,
                    'user_metadata': jsonDecode(request.body)['data'],
                  };
                }
              } else {
                body = {'Key': 'uploaded'};
              }
              return http.Response(
                jsonEncode(body),
                status,
                request: request,
                headers: {'content-type': 'application/json'},
              );
            }),
          );
          addTearDown(client.dispose);
          await client.auth.signInWithPassword(
            email: 'member@example.com',
            password: 'test',
          );
          final service = TestCustomization(client);
          final save = service.save(
            name: ' Member ',
            bio: ' Bio ',
            style: const ProfileStyle(
              frame: 'founder',
              title: 'founder',
              featured: ['platinum', 'challenges'],
            ),
            photo: cover ? null : Uint8List.fromList([255, 216, 255]),
            coverPhoto: cover ? Uint8List.fromList([255, 216, 255]) : null,
          );
          if (fail) {
            await expectLater(save, throwsA(isA<AuthException>()));
          } else {
            await save;
          }
          final updated = requests.singleWhere(
            (r) => r.url.path.endsWith('/user'),
          );
          final data = jsonDecode(updated.body)['data'] as Map;
          expect(data['display_name'], 'Member');
          expect(data['bio'], 'Bio');
          expect(data['profile_style']['frame'], 'orange');
          expect(data['profile_style']['featured'], ['challenges']);
          expect(
            data[cover ? 'cover_url' : 'avatar_url'],
            contains('/member-id/'),
          );
          final uploadIndex = requests.indexWhere(
            (r) => r.method == 'POST' && r.url.path.contains('/storage/'),
          );
          expect(uploadIndex, lessThan(requests.indexOf(updated)));
          final deleted = requests.singleWhere((r) => r.method == 'DELETE');
          expect(
            deleted.url.path,
            contains(cover ? 'profile-covers' : 'profile-avatars'),
          );
          final paths = jsonDecode(deleted.body)['prefixes'] as List;
          expect(paths.single.toString().startsWith('member-id/'), isTrue);
          expect(paths.single.toString().endsWith('old.png'), !fail);
        },
      );
    }
  }
}
