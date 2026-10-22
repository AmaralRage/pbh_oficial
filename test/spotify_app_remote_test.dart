import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/services/spotify_app_remote.dart';
import 'package:pbh_oficial/services/spotify_mobile_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('pbh/spotify_remote');
  final calls = <MethodCall>[];
  late SpotifyAppRemote remote;
  test(
    'completed consent rejected by Spotify is not treated as a user refusal or retried in a loop',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.arguments['authorize'] == true) {
              throw PlatformException(
                code: 'AUTH_NOT_RECOGNIZED',
                message: 'O Spotify não reconheceu a autorização solicitada.',
              );
            }
            throw PlatformException(code: 'AUTH_REQUIRED');
          });
      await expectLater(
        remote.connectForPlayback(),
        throwsA(
          isA<SpotifyRemoteException>().having(
            (e) => e.code,
            'code',
            'AUTH_NOT_RECOGNIZED',
          ),
        ),
      );
      expect(calls.map((c) => c.arguments['authorize']), [false, true]);
      // A later silent refresh must not show consent again.
      await expectLater(
        remote.connect(),
        throwsA(
          isA<SpotifyRemoteException>().having(
            (e) => e.code,
            'code',
            'AUTH_REQUIRED',
          ),
        ),
      );
      expect(calls.last.arguments['authorize'], false);
    },
  );
  test(
    'an unresponsive connection times out, disconnects and allows a retry',
    () async {
      final lateReply = Completer<void>();
      var connections = 0;
      remote = SpotifyAppRemote(
        clientId: 'public-id',
        redirectUri: 'pbh-oficial://spotify-callback',
        connectionTimeout: const Duration(milliseconds: 30),
        commandTimeout: const Duration(milliseconds: 30),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'connect' && ++connections == 1)
              await lateReply.future;
            return null;
          });
      await expectLater(
        remote.connect(),
        throwsA(
          isA<SpotifyRemoteException>().having(
            (e) => e.code,
            'code',
            'TIMEOUT',
          ),
        ),
      );
      await remote.connect();
      expect(calls.where((c) => c.method == 'disconnect').length, 1);
      expect(calls.where((c) => c.method == 'connect').length, 2);
      lateReply.complete();
      await Future<void>.delayed(Duration.zero);
      await remote.connect();
      expect(connections, 3);
    },
  );
  test(
    'an unresponsive playback command finishes without an automatic retry',
    () async {
      final lateReply = Completer<void>();
      remote = SpotifyAppRemote(
        clientId: 'public-id',
        redirectUri: 'pbh-oficial://spotify-callback',
        commandTimeout: const Duration(milliseconds: 30),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            await lateReply.future;
            return null;
          });
      await expectLater(
        remote.play('spotify:playlist:abc'),
        throwsA(
          isA<SpotifyRemoteException>().having(
            (e) => e.code,
            'code',
            'TIMEOUT',
          ),
        ),
      );
      expect(calls.map((c) => c.method), ['play']);
      lateReply.complete();
      await Future<void>.delayed(Duration.zero);
    },
  );
  test('simultaneous playback and polling share a single connection', () async {
    final gate = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          await gate.future;
          return null;
        });
    final first = remote.connect();
    final second = remote.connectForPlayback();
    await Future<void>.delayed(Duration.zero);
    expect(calls.length, 1);
    gate.complete();
    await Future.wait([first, second]);
  });
  test(
    'playback requests consent only for missing remote permission',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.arguments['authorize'] != true)
              throw PlatformException(code: 'AUTH_REQUIRED');
            return null;
          });
      await remote.connectForPlayback();
      expect(calls.map((c) => c.arguments['authorize']), [false, true]);
    },
  );
  test(
    'configuration failures preserve their code without repeating consent',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            throw PlatformException(
              code: 'APP_AUTH_FAILED',
              message: 'Configuração não reconhecida.',
            );
          });
      await expectLater(
        remote.connectForPlayback(),
        throwsA(
          isA<SpotifyRemoteException>().having(
            (e) => e.code,
            'code',
            'APP_AUTH_FAILED',
          ),
        ),
      );
      expect(calls.length, 1);
    },
  );
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
