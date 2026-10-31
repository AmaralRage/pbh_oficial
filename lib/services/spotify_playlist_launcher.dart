import 'package:url_launcher/url_launcher.dart';
import '../core/config/spotify_playlist.dart';

class SpotifyPlaylistLauncher {
  SpotifyPlaylistLauncher({Future<bool> Function(Uri)? launch})
    : _launch = launch ?? _external;
  final Future<bool> Function(Uri) _launch;
  static Future<bool> _external(Uri uri) => launchUrl(
    uri,
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  Future<void> open({required bool native}) async {
    if (native) {
      try {
        if (await _launch(
          Uri.parse('spotify:playlist:$officialSpotifyPlaylistId'),
        ))
          return;
      } catch (_) {}
    }
    if (!await _launch(Uri.parse(officialSpotifyPlaylistUrl)))
      throw StateError('Não foi possível abrir a playlist.');
  }
}
