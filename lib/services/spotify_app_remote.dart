import 'dart:async';
import 'package:flutter/services.dart';
import 'spotify_mobile_api.dart';

/// Talks to the official Android SDK without launching a Spotify content link.
class SpotifyAppRemote {
  SpotifyAppRemote({
    required this.clientId,
    required this.redirectUri,
    MethodChannel channel = const MethodChannel('pbh/spotify_remote'),
    this.connectionTimeout = const Duration(seconds: 50),
    this.commandTimeout = const Duration(seconds: 12),
  }) : _channel = channel;
  final String clientId;
  final String redirectUri;
  final MethodChannel _channel;
  Future<void>? _connecting;
  final Duration connectionTimeout;
  final Duration commandTimeout;

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    try {
      return await _channel
          .invokeMethod<T>(method, args)
          .timeout(method == 'connect' ? connectionTimeout : commandTimeout);
    } on TimeoutException {
      if (method == 'connect') {
        unawaited(
          _channel
              .invokeMethod<void>('disconnect')
              .timeout(commandTimeout)
              .catchError((Object _) {}),
        );
      }
      throw SpotifyRemoteException(
        'TIMEOUT',
        method == 'connect'
            ? 'O Spotify não respondeu à conexão. Confira se ele está conectado à internet e tente novamente. Código: TIMEOUT.'
            : 'O Spotify não confirmou o comando. Confira se a música começou antes de tentar novamente. Código: TIMEOUT.',
      );
    } on PlatformException catch (error) {
      throw SpotifyRemoteException(
        error.code,
        error.message ??
            'Não foi possível controlar o Spotify. Conecte novamente.',
      );
    }
  }

  Future<void> connect({bool authorize = false}) async {
    final pending = _connecting;
    if (pending != null) return pending;
    final operation = _invoke<void>('connect', {
      'clientId': clientId,
      'redirectUri': redirectUri,
      'authorize': authorize,
    });
    _connecting = operation;
    try {
      await operation;
    } finally {
      if (identical(_connecting, operation)) _connecting = null;
    }
  }

  /// Only a user-triggered command may ask for missing Remote permission.
  Future<void> connectForPlayback() async {
    try {
      await connect();
    } on SpotifyRemoteException catch (error) {
      if (error.code != 'AUTH_REQUIRED') rethrow;
      await connect(authorize: true);
    }
  }

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

class SpotifyRemoteException extends SpotifyMobileException {
  const SpotifyRemoteException(this.code, super.message);
  final String code;
}
