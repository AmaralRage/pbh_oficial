import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js;

import 'package:flutter/foundation.dart';

import '../core/config/spotify_playlist.dart';
import '../models/spotify_track.dart';
import 'lyrics_service.dart';

class SpotifyPlaybackController extends ChangeNotifier {
  SpotifyPlaybackController._() {
    html.window.on['pbh-spotify-config'].listen((event) {
      isConfigured = _detail(event)['configured'] == true;
      notifyListeners();
    });
    html.window.on['pbh-spotify-auth'].listen((event) {
      isAuthenticated = _detail(event)['authenticated'] == true;
      isBusy = false;
      notifyListeners();
    });
    html.window.on['pbh-spotify-ready'].listen((event) {
      isReady = _detail(event)['ready'] == true;
      notifyListeners();
    });
    html.window.on['pbh-spotify-state'].listen(_onPlaybackState);
    html.window.on['pbh-spotify-error'].listen((event) {
      error = _detail(event)['message'] as String?;
      isBusy = false;
      notifyListeners();
    });

    isConfigured = clientId.isNotEmpty;
    if (isConfigured) {
      _invoke('pbhSpotifyInitialize', [clientId]);
    }
  }

  static final SpotifyPlaybackController instance = SpotifyPlaybackController._();
  static const clientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');

  bool isConfigured = false;
  bool isAuthenticated = false;
  bool isReady = false;
  bool isPlaying = false;
  bool isBusy = false;
  bool opened = false;
  bool expanded = false;
  String? error;
  SpotifyTrack? track;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  String? lyrics;
  bool lyricsLoading = false;
  String? lyricsError;
  String? _lyricsTrackUri;

  Map<String, dynamic> _detail(html.Event event) {
    final detail = (event as html.CustomEvent).detail;
    if (detail is String) return jsonDecode(detail) as Map<String, dynamic>;
    return detail is Map ? Map<String, dynamic>.from(detail) : <String, dynamic>{};
  }

  Future<void> _invoke(String method, [List<dynamic> arguments = const []]) async {
    final result = js.callMethod<dynamic>(html.window, method, arguments);
    if (result != null && js.hasProperty(result, 'then')) {
      await js.promiseToFuture<dynamic>(result);
    }
  }

  void _onPlaybackState(html.Event event) {
    final data = _detail(event);
    isPlaying = data['isPlaying'] == true;
    position = Duration(milliseconds: (data['position'] as num?)?.round() ?? 0);
    duration = Duration(milliseconds: (data['duration'] as num?)?.round() ?? 0);
    final trackData = data['track'];
    final nextTrack = trackData is Map
        ? SpotifyTrack.fromMap(Map<String, dynamic>.from(trackData))
        : null;
    if (nextTrack?.uri != track?.uri) {
      track = nextTrack;
      _lyricsTrackUri = null;
      lyrics = null;
      lyricsError = null;
      lyricsLoading = false;
    }
    if (nextTrack != null && duration > Duration.zero && _lyricsTrackUri != nextTrack.uri) {
      _loadLyricsForCurrentTrack();
    }
    if (nextTrack != null) opened = true;
    notifyListeners();
  }

  Future<void> _loadLyricsForCurrentTrack() async {
    final selectedTrack = track;
    if (selectedTrack == null || selectedTrack.uri.isEmpty) {
      _lyricsTrackUri = null;
      lyrics = null;
      lyricsError = null;
      lyricsLoading = false;
      return;
    }
    if (_lyricsTrackUri == selectedTrack.uri && (lyrics != null || lyricsLoading || lyricsError != null)) return;
    _lyricsTrackUri = selectedTrack.uri;
    lyrics = null;
    lyricsError = null;
    lyricsLoading = true;
    notifyListeners();
    try {
      final result = await LyricsService.instance.lyricsFor(selectedTrack, duration);
      if (track?.uri != selectedTrack.uri) return;
      lyrics = result;
      if (result == null) lyricsError = 'A letra desta faixa não está disponível.';
    } on LyricsUnavailableException catch (exception) {
      if (track?.uri != selectedTrack.uri) return;
      lyricsError = exception.message;
    } finally {
      if (track?.uri == selectedTrack.uri) {
        lyricsLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retryLyrics() async {
    if (track == null || lyricsLoading) return;
    _lyricsTrackUri = null;
    lyrics = null;
    lyricsError = null;
    await _loadLyricsForCurrentTrack();
  }

  Future<void> connect() async {
    error = null;
    isBusy = true;
    notifyListeners();
    try {
      await _invoke('pbhSpotifyLogin');
    } catch (exception) {
      error = exception.toString();
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> startPlaylist([String playlistId = officialSpotifyPlaylistId]) async {
    if (!isAuthenticated) {
      await connect();
      return;
    }
    error = null;
    isBusy = true;
    notifyListeners();
    try {
      await _invoke('pbhSpotifyStartPlaylist', [playlistId]);
      opened = true;
      expanded = true;
    } catch (exception) {
      error = exception.toString().replaceFirst('Exception: ', '');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> togglePlayback() => _invoke('pbhSpotifyToggle');
  Future<void> nextTrack() => _invoke('pbhSpotifyNext');
  Future<void> previousTrack() => _invoke('pbhSpotifyPrevious');
  Future<void> seek(Duration value) => _invoke('pbhSpotifySeek', [value.inMilliseconds]);

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

  void openCurrentTrack() {
    if (track != null) _invoke('pbhSpotifyOpenTrack', [track!.uri]);
  }

  void disconnect() {
    _invoke('pbhSpotifyLogout');
    isAuthenticated = false;
    isReady = false;
    isPlaying = false;
    track = null;
    lyrics = null;
    lyricsError = null;
    lyricsLoading = false;
    _lyricsTrackUri = null;
    opened = false;
    expanded = false;
    notifyListeners();
  }
}
