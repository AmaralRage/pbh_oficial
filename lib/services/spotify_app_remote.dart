import 'package:flutter/services.dart';
import 'spotify_mobile_api.dart';

/// Talks to the official Android SDK without launching a Spotify content link.
class SpotifyAppRemote {
  SpotifyAppRemote({
    required this.clientId,
    required this.redirectUri,
    MethodChannel channel = const MethodChannel('pbh/spotify_remote'),
  }) : _channel = channel;
  final String clientId;
  final String redirectUri;
  final MethodChannel _channel;

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (error) {
      throw SpotifyMobileException(
        error.message ??
            'Não foi possível controlar o Spotify. Conecte novamente.',
      );
    }
  }

  Future<void> connect({bool authorize = false}) => _invoke('connect', {
    'clientId': clientId,
    'redirectUri': redirectUri,
    'authorize': authorize,
  });
  Future<void> play(String uri, {int? index}) =>
      _invoke('play', {'uri': uri, if (index != null) 'index': index});
  Future<void> command(String command, [Map<String, dynamic>? args]) =>
      _invoke(command, args);
  Future<Map<String, dynamic>?> state() async {
    final data = await _invoke<Map>('state');
    if (data == null) return null;
    Map<String, dynamic> convert(Map map) => map.map(
      (key, value) => MapEntry(
        key.toString(),
        value is Map
            ? convert(value)
            : value is List
            ? value.map((item) => item is Map ? convert(item) : item).toList()
            : value,
      ),
    );
    return convert(data);
  }

  Future<void> disconnect() => _invoke('disconnect');
}
