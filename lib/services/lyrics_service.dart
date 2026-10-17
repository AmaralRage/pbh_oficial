import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/spotify_track.dart';

class LyricsService {
  LyricsService._();

  static final LyricsService instance = LyricsService._();
  final http.Client _client = http.Client();
  final Map<String, String?> _cache = {};

  Future<String?> lyricsFor(SpotifyTrack track, Duration duration) async {
    if (_cache.containsKey(track.uri)) return _cache[track.uri];

    final query = <String, String>{
      'track_name': track.name,
      'artist_name': track.artists,
      if (track.album.isNotEmpty) 'album_name': track.album,
      if (duration.inSeconds > 0) 'duration': '${duration.inSeconds}',
    };
    final uri = Uri.https('lrclib.net', '/api/get', query);
    try {
      final response = await _client.get(uri, headers: const {
        'X-User-Agent': 'PBH Oficial/1.0 (https://pbh-oficial.vercel.app)',
      });
      if (response.statusCode == 404) {
        _cache[track.uri] = null;
        return null;
      }
      if (response.statusCode == 429) {
        throw const LyricsUnavailableException('Muitas consultas de letras em sequência. Tente novamente em instantes.');
      }
      if (response.statusCode != 200) {
        throw const LyricsUnavailableException('Não foi possível carregar a letra agora.');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      var text = (data['plainLyrics'] as String?)?.trim() ?? '';
      if (text.isEmpty) {
        // Display timed lyrics as readable text without highlighting against playback.
        final synced = (data['syncedLyrics'] as String?) ?? '';
        text = synced
            .split('\n')
            .map((line) => line.replaceFirst(RegExp(r'^\s*\[[0-9:.]+\]\s*'), '').trim())
            .where((line) => line.isNotEmpty && !line.startsWith('['))
            .join('\n');
      }
      final result = text.isEmpty ? null : text;
      _cache[track.uri] = result;
      return result;
    } on LyricsUnavailableException {
      rethrow;
    } catch (_) {
      throw const LyricsUnavailableException('Sem conexão para carregar as letras.');
    }
  }
}

class LyricsUnavailableException implements Exception {
  const LyricsUnavailableException(this.message);
  final String message;
}
