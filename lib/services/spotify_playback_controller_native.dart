import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/spotify_playlist.dart';
import '../models/spotify_track.dart';
import 'lyrics_service.dart';
import 'spotify_mobile_api.dart';
import 'spotify_app_remote.dart';

/// Controls Spotify on the phone; the official Spotify app renders the audio.
class SpotifyPlaybackController extends ChangeNotifier
    with WidgetsBindingObserver {
  SpotifyPlaybackController._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final SpotifyPlaybackController instance =
      SpotifyPlaybackController._();
  static const clientId = String.fromEnvironment(
    'SPOTIFY_CLIENT_ID',
    defaultValue: '59ea8a21516947b1936233d03ea53f31',
  );
  static const redirectUri = 'pbh-oficial://spotify-callback';
  final _api = SpotifyMobileApi(clientId: clientId);
  final _remote = SpotifyAppRemote(
    clientId: clientId,
    redirectUri: redirectUri,
  );
  Timer? _poll;
  Timer? _ticker;
  bool _polling = false;
  bool _foreground = true;
  int _generation = 0;
  String? _deviceId;
  DateTime? _sampleAt;
  Duration _samplePosition = Duration.zero;

  bool get isConfigured =>
      clientId.isNotEmpty && (Platform.isAndroid || Platform.isIOS);
  bool get isAuthenticated => _api.isAuthenticated;
  // A Connect device is discovered on Play; absence must not disable that button.
  bool get isReady => isAuthenticated;
  bool isPlaying = false;
  bool shuffleEnabled = false;
  int repeatMode = 0;
  bool isBusy = false;
  bool opened = false;
  bool expanded = false;
  String? error;
  SpotifyTrack? track;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  String? lyrics;
  List<LyricLine> lyricLines = const [];
  bool lyricsAreSynced = false;
  bool lyricsLoading = false;
  String? lyricsError;

  int get activeLyricIndex {
    if (!lyricsAreSynced) return -1;
    var active = -1;
    for (var index = 0; index < lyricLines.length; index++) {
      final time = lyricLines[index].timestamp;
      if (time != null && time > position) break;
      if (time != null) active = index;
    }
    return active;
  }

  String _random(int length) {
    final random = Random.secure();
    return base64UrlEncode(
      List.generate(length, (_) => random.nextInt(256)),
    ).replaceAll('=', '');
  }

  Future<void> connect({bool forceConsent = false}) async {
    if (isBusy) return;
    if (!isConfigured) {
      error = 'O Spotify ainda não foi configurado para este aparelho.';
      notifyListeners();
      return;
    }
    final generation = _generation;
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      final verifier = _random(48);
      final state = _random(24);
      final url = Uri.https('accounts.spotify.com', '/authorize', {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'state': state,
        'code_challenge_method': 'S256',
        'code_challenge': base64UrlEncode(
          sha256.convert(utf8.encode(verifier)).bytes,
        ).replaceAll('=', ''),
        'scope':
            'user-read-playback-state user-modify-playback-state playlist-read-private app-remote-control',
        if (forceConsent) 'show_dialog': 'true',
      });
      final callback = Uri.parse(
        await FlutterWebAuth2.authenticate(
          url: url.toString(),
          callbackUrlScheme: 'pbh-oficial',
        ),
      );
      if (generation != _generation) return;
      if (callback.scheme != 'pbh-oficial' ||
          callback.host != 'spotify-callback' ||
          callback.queryParameters['state'] != state) {
        throw const SpotifyMobileException(
          'Não foi possível validar o retorno do Spotify. Tente novamente.',
        );
      }
      if (callback.queryParameters.containsKey('error')) {
        throw const SpotifyMobileException(
          'A conexão com o Spotify foi cancelada.',
        );
      }
      final code = callback.queryParameters['code'];
      if (code == null) {
        throw const SpotifyMobileException(
          'O Spotify não retornou a autorização.',
        );
      }
      await _api.authorize(code, verifier, redirectUri);
      if (generation != _generation) return;
      if (Platform.isAndroid) await _remote.connect(authorize: true);
      if (generation != _generation) return;
      _startUpdates();
      await _refreshPlayback();
    } catch (exception) {
      if (generation != _generation) return;
      error = exception is PlatformException && exception.code == 'CANCELED'
          ? 'A conexão com o Spotify foi cancelada.'
          : _message(exception);
    } finally {
      if (generation == _generation) {
        isBusy = false;
        notifyListeners();
      }
    }
  }

  void _startUpdates() {
    _stopUpdates();
    if (!_foreground || !isAuthenticated) return;
    _poll = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshPlayback(),
    );
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      final sampleAt = _sampleAt;
      if (!isPlaying || sampleAt == null) return;
      final elapsed = _samplePosition + DateTime.now().difference(sampleAt);
      position = elapsed > duration ? duration : elapsed;
      notifyListeners();
    });
  }

  void _stopUpdates() {
    _poll?.cancel();
    _ticker?.cancel();
    _poll = null;
    _ticker = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && isAuthenticated) {
      _startUpdates();
      _refreshPlayback();
    } else {
      _stopUpdates();
    }
  }

  Future<void> _refreshPlayback() async {
    if (_polling || !isAuthenticated || !_foreground) return;
    _polling = true;
    final generation = _generation;
    try {
      final Map<String, dynamic>? data;
      if (Platform.isAndroid) {
        await _remote.connect();
        data = await _remote.state();
      } else {
        data = await _api.request('/me/player');
      }
      if (generation != _generation) return;
      _deviceId = (data?['device'] as Map?)?['id'] as String?;
      isPlaying = data?['is_playing'] == true;
      shuffleEnabled = data?['shuffle_state'] == true;
      repeatMode = switch (data?['repeat_state']) {
        'context' => 1,
        'track' => 2,
        _ => 0,
      };
      final item = data?['item'];
      final next = item is Map<String, dynamic> && item['type'] == 'track'
          ? _track(item)
          : null;
      duration = Duration(
        milliseconds: item is Map
            ? (item['duration_ms'] as num?)?.toInt() ?? 0
            : 0,
      );
      position = Duration(
        milliseconds: (data?['progress_ms'] as num?)?.toInt() ?? 0,
      );
      _sampleAt = DateTime.now();
      _samplePosition = position;
      if (next?.uri != track?.uri) {
        track = next;
        _resetLyrics();
        if (next != null) unawaited(_loadLyrics());
      }
      if (next != null) opened = true;
      notifyListeners();
    } catch (exception) {
      if (generation == _generation) {
        error = _message(exception);
        if (!isAuthenticated) _stopUpdates();
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  SpotifyTrack _track(Map<String, dynamic> item, {int? playlistPosition}) {
    final album = item['album'] as Map?;
    final images = album?['images'] as List? ?? const [];
    return SpotifyTrack(
      uri: item['uri'] as String? ?? '',
      name: item['name'] as String? ?? '',
      artists: (item['artists'] as List? ?? const [])
          .map((artist) => artist['name'])
          .join(', '),
      album: album?['name'] as String? ?? '',
      imageUrl: images.isEmpty ? '' : images.first['url'] as String? ?? '',
      spotifyUrl: (item['external_urls'] as Map?)?['spotify'] as String? ?? '',
      playlistPosition: playlistPosition,
    );
  }

  Future<List<SpotifyTrack>> loadPlaylistTracks([
    String playlistId = officialSpotifyPlaylistId,
  ]) async {
    final tracks = <SpotifyTrack>[];
    var offset = 0;
    while (true) {
      final data = await _api.request(
        '/playlists/${Uri.encodeComponent(playlistId)}/items',
        query: {'limit': '50', 'offset': '$offset', 'market': 'BR'},
      );
      final items = data?['items'] as List? ?? const [];
      for (var index = 0; index < items.length; index++) {
        final entry = items[index] as Map?;
        final item = entry?['item'] ?? entry?['track'];
        if (item is Map<String, dynamic> &&
            item['type'] == 'track' &&
            item['uri'] != null) {
          tracks.add(_track(item, playlistPosition: offset + index));
        }
      }
      offset += items.length;
      if (items.isEmpty || data?['next'] == null) break;
    }
    return tracks;
  }

  Future<String?> _phoneDevice() async {
    final data = await _api.request('/me/player/devices');
    final phones = (data?['devices'] as List? ?? const [])
        .whereType<Map>()
        .where(
          (device) =>
              device['type'] == 'Smartphone' &&
              device['is_restricted'] != true &&
              device['id'] != null,
        )
        .toList();
    if (phones.isEmpty) return null;
    final active = phones.where((device) => device['is_active'] == true);
    return (active.isNotEmpty ? active.first : phones.first)['id'] as String;
  }

  Future<void> startPlaylist([
    String playlistId = officialSpotifyPlaylistId,
  ]) async {
    if (!isAuthenticated) {
      await connect();
      if (!isAuthenticated || error != null) return;
    }
    await _play(playlistId);
  }

  Future<void> playPlaylistTrack(
    SpotifyTrack selectedTrack, [
    String playlistId = officialSpotifyPlaylistId,
  ]) => _play(playlistId, selectedTrack: selectedTrack, rethrowError: true);

  Future<void> _play(
    String playlistId, {
    SpotifyTrack? selectedTrack,
    bool rethrowError = false,
  }) async {
    await _command(() async {
      if (Platform.isAndroid) {
        await _remote.connectForPlayback();
        if (selectedTrack?.playlistPosition != null) {
          await _remote.play(
            'spotify:playlist:$playlistId',
            index: selectedTrack!.playlistPosition,
          );
        } else {
          await _remote.play(
            selectedTrack?.uri ?? 'spotify:playlist:$playlistId',
          );
        }
        opened = true;
        expanded = true;
        return;
      }
      _deviceId = await _phoneDevice();
      if (_deviceId == null) {
        throw const SpotifyMobileException(
          'O Spotify deste celular ainda não está disponível para reprodução. Ative-o pelo botão “Abrir playlist no Spotify” e volte ao player do PBH.',
        );
      }
      await _api.request(
        '/me/player/play',
        method: 'PUT',
        query: {'device_id': _deviceId!},
        body: {
          'context_uri': 'spotify:playlist:$playlistId',
          if (selectedTrack != null)
            'offset': selectedTrack.playlistPosition != null
                ? {'position': selectedTrack.playlistPosition}
                : {'uri': selectedTrack.uri},
        },
      );
      opened = true;
      expanded = true;
    }, rethrowError: rethrowError);
  }

  Future<void> _command(
    Future<void> Function() action, {
    bool rethrowError = false,
  }) async {
    if (isBusy) return;
    final generation = _generation;
    isBusy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      if (generation == _generation) await _refreshPlayback();
    } catch (exception) {
      if (generation == _generation) error = _message(exception);
      if (rethrowError) rethrow;
    } finally {
      if (generation == _generation) {
        isBusy = false;
        notifyListeners();
      }
    }
  }

  Future<void> _control(
    String path, {
    String method = 'PUT',
    Map<String, String> query = const {},
  }) => _command(() async {
    if (Platform.isAndroid) {
      await _remote.connectForPlayback();
      switch (path) {
        case 'play':
          await _remote.command('resume');
        case 'pause':
          await _remote.command('pause');
        case 'next':
          await _remote.command('next');
        case 'previous':
          await _remote.command('previous');
        case 'seek':
          await _remote.command('seek', {
            'position': int.parse(query['position_ms']!),
          });
        case 'shuffle':
          await _remote.command('shuffle', {
            'enabled': query['state'] == 'true',
          });
        case 'repeat':
          await _remote.command('repeat', {
            'mode': const {'off': 0, 'context': 1, 'track': 2}[query['state']],
          });
      }
      return;
    }
    await _api.request(
      '/me/player/$path',
      method: method,
      query: {if (_deviceId != null) 'device_id': _deviceId!, ...query},
    );
  });
  Future<void> togglePlayback() => _control(isPlaying ? 'pause' : 'play');
  Future<void> nextTrack() => _control('next', method: 'POST');
  Future<void> previousTrack() => _control('previous', method: 'POST');
  Future<void> seek(Duration value) => _control(
    'seek',
    query: {
      'position_ms':
          '${value.inMilliseconds.clamp(0, duration.inMilliseconds)}',
    },
  );
  Future<void> setShuffle(bool enabled) =>
      _control('shuffle', query: {'state': '$enabled'});
  Future<void> setRepeatMode(int mode) => _control(
    'repeat',
    query: {
      'state': const ['off', 'context', 'track'][mode.clamp(0, 2)],
    },
  );

  void _resetLyrics() {
    lyrics = null;
    lyricLines = const [];
    lyricsAreSynced = false;
    lyricsLoading = false;
    lyricsError = null;
  }

  Future<void> _loadLyrics() async {
    final selected = track;
    final generation = _generation;
    if (selected == null) return;
    lyricsLoading = true;
    notifyListeners();
    try {
      final result = await LyricsService.instance.lyricsFor(selected, duration);
      if (generation != _generation || track?.uri != selected.uri) return;
      lyrics = result?.plainText;
      lyricLines = result?.lines ?? const [];
      lyricsAreSynced = result?.isSynced ?? false;
      lyricsError = result == null
          ? 'A letra desta faixa não está disponível.'
          : null;
    } catch (exception) {
      if (generation == _generation && track?.uri == selected.uri) {
        lyricsError = exception is LyricsUnavailableException
            ? exception.message
            : 'Não foi possível carregar a letra.';
      }
    } finally {
      if (generation == _generation && track?.uri == selected.uri) {
        lyricsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryLyrics() async {
    if (lyricsLoading) return;
    _resetLyrics();
    await _loadLyrics();
  }

  Future<void> _launchSpotify(String uri) async {
    try {
      if (await launchUrl(
        Uri.parse(uri),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } on PlatformException catch (_) {
      // Surface an installation hint instead of an unhandled platform error.
    }
    throw const SpotifyMobileException(
      'Instale o aplicativo Spotify neste celular para reproduzir.',
    );
  }

  void openCurrentTrack() {
    if (track != null) openTrack(track!);
  }

  void openTrack(SpotifyTrack selectedTrack) {
    unawaited(
      _launchSpotify(selectedTrack.uri).catchError((Object exception) {
        error = _message(exception);
        notifyListeners();
      }),
    );
  }

  void open() {
    opened = true;
    expanded = true;
    notifyListeners();
  }

  void minimize() {
    expanded = false;
    notifyListeners();
  }

  void expand() {
    expanded = true;
    notifyListeners();
  }

  String _message(Object exception) => exception is SpotifyMobileException
      ? exception.message
      : 'Não foi possível conectar ao Spotify. Verifique a internet e tente novamente.';

  void disconnect() {
    _generation++;
    if (Platform.isAndroid)
      unawaited(_remote.disconnect().catchError((Object _) {}));
    _stopUpdates();
    _api.clear();
    _deviceId = null;
    _sampleAt = null;
    isBusy = false;
    isPlaying = false;
    shuffleEnabled = false;
    repeatMode = 0;
    opened = false;
    expanded = false;
    track = null;
    position = Duration.zero;
    duration = Duration.zero;
    error = null;
    _resetLyrics();
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
