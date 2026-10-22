import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pbh_oficial/core/theme/pbh_palette.dart';
import 'package:pbh_oficial/models/profile_style.dart';
import 'package:pbh_oficial/services/appearance_service.dart';
import 'package:pbh_oficial/widgets/theme_choices.dart';

class PaletteProbe extends StatefulWidget {
  const PaletteProbe({super.key});
  @override
  State<PaletteProbe> createState() => _PaletteProbeState();
}

class _PaletteProbeState extends State<PaletteProbe> {
  var count = 0;
  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('${context.pbhColors.id}:$count'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('palettes have readable text and founder remains exclusive', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    for (final palette in PbhPalette.catalog) {
      expect(
        contrast(palette.textPrimary, palette.surface),
        greaterThanOrEqualTo(4.5),
        reason: palette.id,
      );
      expect(
        contrast(palette.textSecondary, palette.surface),
        greaterThanOrEqualTo(4.5),
        reason: palette.id,
      );
      expect(
        contrast(palette.onAccent, palette.accent),
        greaterThanOrEqualTo(4.5),
        reason: palette.id,
      );
    }
    expect(PbhPalette.resolve('founder').id, 'pbh');
    expect(PbhPalette.resolve('unknown').id, 'pbh');
    expect(PbhPalette.resolve('founder', founder: true).id, 'founder');
    expect(
      const ProfileStyle(
        profileTheme: 'founder',
      ).validated(founder: false, completed: 100, earned: []).profileTheme,
      'pbh',
    );
    expect(
      ProfileStyle.fromMetadata({
        'profile_style': const ProfileStyle(profileTheme: 'nova').toMap(),
      }).profileTheme,
      'nova',
    );
    expect(ProfileStyle.fromMetadata({}).profileTheme, 'app');
  });
  test(
    'appearance survives restart and account changes without leaking founder themes',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      var fail = false;
      final user = {
        'id': 'member',
        'aud': 'authenticated',
        'email': 'member@example.com',
        'created_at': '2026-01-01T00:00:00Z',
        'app_metadata': {},
        'user_metadata': <String, dynamic>{'app_theme': 'galactic'},
      };
      final client = SupabaseClient(
        'https://test.supabase.co',
        'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
        httpClient: MockClient((request) async {
          var status = 200;
          Object body = {};
          if (request.url.path.endsWith('/token')) {
            body = {
              'access_token': 'test-token',
              'refresh_token': 'refresh',
              'expires_in': 3600,
              'token_type': 'bearer',
              'user': user,
            };
          } else if (request.url.path.endsWith('/user')) {
            if (fail) {
              status = 500;
              body = {'msg': 'offline'};
            } else {
              (user['user_metadata'] as Map).addAll(
                jsonDecode(request.body)['data'] as Map,
              );
              body = user;
            }
          }
          return http.Response(
            jsonEncode(body),
            status,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final service = AppearanceService();
      addTearDown(() async {
        service.dispose();
        await client.dispose();
      });
      await service.bind(null);
      await service.apply('starlight');
      final reopened = AppearanceService();
      await reopened.bind(null);
      expect(reopened.palette.id, 'starlight');
      reopened.dispose();
      await client.auth.signInWithPassword(
        email: 'member@example.com',
        password: 'test',
      );
      await service.bind(client);
      await service.refresh();
      expect(service.palette.id, 'galactic');
      await expectLater(service.apply('founder'), throwsStateError);
      await service.apply('nova');
      expect(service.palette.id, 'nova');
      fail = true;
      await expectLater(service.apply('cosmic'), throwsA(isA<AuthException>()));
      expect(service.palette.id, 'nova');
      await client.auth.signOut();
      await service.refresh();
      expect(service.palette.id, 'starlight');
    },
  );
  testWidgets(
    'theme selection preserves widget state and nested profiles use their own palette',
    (tester) async {
      Widget app(String id) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [PbhPalette.resolve(id)]),
        home: Column(
          children: [
            const PaletteProbe(),
            Theme(
              data: ThemeData.dark().copyWith(
                extensions: [PbhPalette.resolve('nova')],
              ),
              child: const PaletteProbe(),
            ),
          ],
        ),
      );
      await tester.pumpWidget(app('starlight'));
      await tester.tap(find.text('starlight:0'));
      await tester.pump();
      await tester.pumpWidget(app('galactic'));
      await tester.pumpAndSettle();
      expect(find.text('galactic:1'), findsOneWidget);
      expect(find.text('nova:0'), findsOneWidget);
    },
  );
  testWidgets(
    'theme gallery offers follow-app and hides founder choices for members',
    (tester) async {
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ThemeChoices(
                selected: 'app',
                allowFollowApp: true,
                onSelected: (id) => picked = id,
              ),
            ),
          ),
        ),
      );
      expect(find.text('Legado do fundador'), findsNothing);
      await tester.tap(find.text('Azul estelar'));
      expect(picked, 'starlight');
      expect(find.text('Acompanhar tema do app'), findsOneWidget);
    },
  );
}
