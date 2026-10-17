import 'package:flutter/foundation.dart';

import '../models/spotify_track.dart';
import 'lyrics_service.dart';

class SpotifyPlaybackController extends ChangeNotifier {
  SpotifyPlaybackController._();
  static final SpotifyPlaybackController instance = SpotifyPlaybackController._();

  bool get isConfigured => false;
  bool get isAuthenticated => false;
  bool get isReady => false;
  bool get isPlaying => false;
  bool get shuffleEnabled => false;
  int get repeatMode => 0;
  bool get isBusy => false;
  bool get opened => false;
  bool get expanded => false;
  String? get error => 'O player Spotify está disponível na versão web do PBH Oficial.';
  SpotifyTrack? get track => null;
  Duration get position => Duration.zero;
  Duration get duration => Duration.zero;
  String? get lyrics => null;
  List<LyricLine> get lyricLines => const [];
  bool get lyricsAreSynced => false;
  int get activeLyricIndex => -1;
  bool get lyricsLoading => false;
  String? get lyricsError => null;

  Future<void> connect() async {}
  Future<void> retryLyrics() async {}
  Future<void> startPlaylist(String playlistId) async {}
  Future<void> togglePlayback() async {}
  Future<void> nextTrack() async {}
  Future<void> previousTrack() async {}
  Future<void> seek(Duration position) async {}
  Future<List<SpotifyTrack>> searchTracks(String query) async => const [];
  Future<void> playTrack(SpotifyTrack track) async {}
  Future<void> setShuffle(bool enabled) async {}
  Future<void> setRepeatMode(int mode) async {}
  void open() {}
  void minimize() {}
  void expand() {}
  void openCurrentTrack() {}
  void openTrack(SpotifyTrack track) {}
  void disconnect() {}
}
