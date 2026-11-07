import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:google_fonts/src/google_fonts_base.dart' as fonts;
import 'package:pbh_oficial/screens/app_startup_screen.dart';
import 'package:pbh_oficial/screens/launch_screen.dart';
import 'package:pbh_oficial/services/community_post_navigation.dart';

class _Fonts extends AssetManifest {
  @override
  List<String> listAssets() => ['Manrope-Regular.ttf'];
  @override
  List<AssetMetadata>? getAssetVariants(String key) => null;
}

void main() {
  const id = 'bc500000-0000-4000-8000-000000000003';
  setUp(() {
    CommunityPostNavigation.pending.value = null;
    fonts.assetManifest = _Fonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (key == 'AssetManifest.bin')
            return const StandardMessageCodec().encodeMessage(
              <String, Object>{},
            );
          if (key == 'Manrope-Regular.ttf') return ByteData(0);
          if (key.endsWith('.png'))
            return ByteData.sublistView(
              base64Decode(
                'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
              ),
            );
          return null;
        });
  });
  tearDown(() {
    CommunityPostNavigation.pending.value = null;
    fonts.assetManifest = null;
    fonts.clearCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'cold notification waits for startup then bypasses the manual start button without losing destination',
    (tester) async {
      final ready = Completer<void>();
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: AppStartupScreen(
            initialize: () => ready.future,
            child: LaunchScreen(
              onStart: () {
                starts++;
                expect(CommunityPostNavigation.pending.value, id);
              },
            ),
          ),
        ),
      );
      CommunityPostNavigation.fromNotification({
        'recipient_id': 'member',
        'destination_url': 'https://pbh-oficial.vercel.app/?community_post=$id',
      }, 'member');
      expect(starts, 0);
      ready.complete();
      await tester.pump();
      await tester.pump();
      expect(starts, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'ordinary launch stays manual, but a later notification advances exactly once',
    (tester) async {
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(home: LaunchScreen(onStart: () => starts++)),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(starts, 0);
      CommunityPostNavigation.fromLocalPayload(
        jsonEncode({
          'recipient_id': 'member',
          'destination_url':
              'https://pbh-oficial.vercel.app/?community_post=$id',
        }),
        'member',
      );
      await tester.pump();
      expect(starts, 1);
      CommunityPostNavigation.pending.value = null;
      CommunityPostNavigation.pending.value = id;
      await tester.pump();
      expect(starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
