import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/widgets/community_identity.dart';

void main() {
  const owner = 'ad300000-0000-4000-8000-000000000001';
  const other = 'ad300000-0000-4000-8000-000000000002';
  late SupabaseClient client;
  late Map<String, dynamic> metadata;
  late String otherName;
  late int identityReads;
  Map<String, dynamic> user() => {
    'id': owner,
    'aud': 'authenticated',
    'email': 'member@example.invalid',
    'created_at': '2026-10-30T12:00:00Z',
    'app_metadata': {},
    'user_metadata': metadata,
  };
  setUp(() async {
    metadata = {'display_name': 'Current profile', 'avatar_url': 'current.jpg'};
    otherName = 'Other profile';
    identityReads = 0;
    client = SupabaseClient(
      'https://test.supabase.co',
      'public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        Object body;
        if (request.url.path.endsWith('/token')) {
          body = {
            'access_token': 'token',
            'refresh_token': 'refresh',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user(),
          };
        } else if (request.url.path.endsWith('/user')) {
          if (request.method == 'PUT')
            metadata = Map<String, dynamic>.from(
              (jsonDecode(request.body) as Map)['data'] as Map,
            );
          body = user();
        } else {
          identityReads++;
          body = [
            {
              'user_id': other,
              'name': otherName,
              'avatar_url': null,
              'founder': false,
            },
          ];
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await client.auth.signInWithPassword(
      email: 'member@example.invalid',
      password: 'password',
    );
  });
  tearDown(() => client.dispose());
  Widget identity(String id) => MaterialApp(
    home: CommunityIdentityBuilder(
      client: client,
      userId: id,
      name: 'Stale feed',
      avatarUrl: 'old.jpg',
      builder: (_, value) => Text('${value.name}|${value.avatarUrl ?? 'none'}'),
    ),
  );
  testWidgets(
    'own name and avatar follow profile edits and removal immediately',
    (tester) async {
      await tester.pumpWidget(identity(owner));
      expect(find.text('Current profile|current.jpg'), findsOneWidget);
      await tester.runAsync(
        () => client.auth.updateUser(
          UserAttributes(
            data: {'display_name': 'New profile', 'avatar_url': ''},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('New profile|'), findsOneWidget);
      expect(identityReads, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('other authors refresh automatically without reopening the feed', (
    tester,
  ) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(identity(other));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(
      find.text('Other profile|none'),
      findsOneWidget,
      reason:
          'reads=$identityReads text=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}',
    );
    otherName = 'Changed remotely';
    // The request coalescer uses wall time; expire its two-second cache.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 2100));
    });
    await tester.pump(const Duration(seconds: 30));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pumpAndSettle();
    expect(find.text('Changed remotely|none'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
