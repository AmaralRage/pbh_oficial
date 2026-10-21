import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/services/spotify_app_remote.dart';
import 'package:pbh_oficial/services/spotify_mobile_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pbh/spotify_remote');
  final calls = <MethodCall>[];
  late SpotifyAppRemote remote;
  setUp(() {
    calls.clear();
    remote = SpotifyAppRemote(
      clientId: 'public-id',
      redirectUri: 'pbh-oficial://spotify-callback',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'state')
            return {
              'is_playing': true,
              'progress_ms': 1000,
              'item': {
                'type': 'track',
                'uri': 'spotify:track:abc',
                'artists': [
                  {'name': 'Artist'},
                ],
                'album': {
                  'images': [
                    {'url': 'https://i.scdn.co/image/abc'},
                  ],
                },
              },
            };
          return null;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test(
    'only explicit account connection requests Spotify authorization',
    () async {
      await remote.connect(authorize: true);
      await remote.connect();
      expect(calls[0].arguments['authorize'], true);
      expect(calls[1].arguments['authorize'], false);
      expect(calls[1].arguments['clientId'], 'public-id');
    },
  );
  test(
    'playlist selection and controls use the native bridge without external links',
    () async {
      await remote.play('spotify:playlist:abc', index: 5);
      await remote.command('pause');
      await remote.command('resume');
      await remote.command('seek', {'position': 30000});
      await remote.disconnect();
      expect(calls.map((c) => c.method), [
        'play',
        'pause',
        'resume',
        'seek',
        'disconnect',
      ]);
      expect(calls.first.arguments, {
        'uri': 'spotify:playlist:abc',
        'index': 5,
      });
    },
  );
  test(
    'native player metadata is converted for track covers and lyrics',
    () async {
      final state = await remote.state();
      expect(state!['item'], isA<Map<String, dynamic>>());
      expect(state['item']['album'], isA<Map<String, dynamic>>());
      expect(state['item']['artists'].first['name'], 'Artist');
    },
  );
  test(
    'authorization errors remain in PBH instead of opening Spotify',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (_) async => throw PlatformException(
              code: 'REMOTE_AUTH',
              message: 'Reconecte o Spotify.',
            ),
          );
      await expectLater(
        remote.connect(),
        throwsA(isA<SpotifyMobileException>()),
      );
    },
  );
}
