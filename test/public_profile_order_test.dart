import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:pbh_oficial/screens/public_member_profile_screen.dart';
import 'package:pbh_oficial/widgets/stat_card.dart';

class _Fonts extends AssetManifest {
  @override
  List<String> listAssets() => ['Manrope-Regular.ttf'];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void main() {
  testWidgets('public profile renders statistics then goal then publications', (
    tester,
  ) async {
    const member = '00000000-0000-0000-0000-000000000001';
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    fonts.assetManifest = _Fonts();
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'flutter/assets',
      (message) async {
        if (utf8.decode(message!.buffer.asUint8List()) == 'Manrope-Regular.ttf')
          return ByteData(0);
        return null;
      },
    );
    await tester.runAsync(
      () => Supabase.initialize(
        url: 'https://test.supabase.co',
        publishableKey: 'public-key',
        authOptions: const FlutterAuthClientOptions(
          autoRefreshToken: false,
          localStorage: EmptyLocalStorage(),
          detectSessionInUri: false,
        ),
        httpClient: MockClient((request) async {
          Object? result = [];
          if (request.url.path.endsWith('community_member_profile'))
            result = {
              'id': member,
              'name': 'Membro',
              'is_own': true,
              'progress_shared': true,
              'style': {
                'frame_effect': 'none',
                'cover_effect': 'none',
                'featured': [],
                'miniatures': [],
              },
              'progress': {
                'completed': 0,
                'total': 62,
                'followers': 0,
                'streak': 0,
              },
            };
          if (request.url.path.endsWith('public_profile_goal'))
            result = {
              'title': 'Meu objetivo de teste',
              'next_step': 'Meu próximo passo',
            };
          return http.Response(
            jsonEncode(result),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
    addTearDown(() async {
      fonts.assetManifest = null;
      fonts.clearCache();
      tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'flutter/assets',
        null,
      );
      await Supabase.instance.dispose();
    });
    await tester.pumpWidget(
      const MaterialApp(home: PublicMemberProfileScreen(userId: member)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    final stats = find.byType(ProfileStats),
        goal = find.text('Meu objetivo de teste'),
        publications = find.text('Ver publicações');
    expect(stats, findsOneWidget);
    expect(goal, findsOneWidget);
    expect(publications, findsOneWidget);
    expect(find.text('Dias de\nsequência'), findsOneWidget);
    expect(find.text('Pessoas que\nacompanham'), findsNothing);
    expect(find.text('Selos de dedicação'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(
      tester.getBottomLeft(stats).dy,
      lessThan(tester.getTopLeft(goal).dy),
    );
    expect(
      tester.getBottomLeft(goal).dy,
      lessThan(tester.getTopLeft(publications).dy),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
