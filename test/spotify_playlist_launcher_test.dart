import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/services/spotify_playlist_launcher.dart';

void main() {
  test(
    'missing native Spotify app falls back to the official web playlist',
    () async {
      final opened = <Uri>[];
      await SpotifyPlaylistLauncher(
        launch: (uri) async {
          opened.add(uri);
          if (uri.scheme == 'spotify') throw StateError('Not installed');
          return true;
        },
      ).open(native: true);
      expect(opened.map((u) => u.scheme), ['spotify', 'https']);
      expect(opened.last.host, 'open.spotify.com');
    },
  );
  test(
    'web never attempts a native app scheme and reports launch failure',
    () async {
      final opened = <Uri>[];
      await expectLater(
        SpotifyPlaylistLauncher(
          launch: (uri) async {
            opened.add(uri);
            return false;
          },
        ).open(native: false),
        throwsStateError,
      );
      expect(opened.single.scheme, 'https');
    },
  );
}
