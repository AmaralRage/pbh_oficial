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
      if (response.statusCode == 429) {
        throw const LyricsUnavailableException('Muitas consultas de letras em sequência. Tente novamente em instantes.');
      }
      Map<String, dynamic>? data;
      if (response.statusCode == 200) {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        final searchUri = Uri.https('lrclib.net', '/api/search', {
          'track_name': track.name,
          'artist_name': track.artists,
        });
        final searchResponse = await _client.get(searchUri, headers: const {
          'X-User-Agent': 'PBH Oficial/1.0 (https://pbh-oficial.vercel.app)',
        });
        if (searchResponse.statusCode == 429) {
          throw const LyricsUnavailableException('Muitas consultas de letras em sequência. Tente novamente em instantes.');
        }
        if (searchResponse.statusCode == 200) {
          final records = jsonDecode(searchResponse.body) as List<dynamic>;
          final matching = records.whereType<Map<String, dynamic>>().where((record) {
            final titleMatches = (record['trackName'] as String? ?? '').toLowerCase() == track.name.toLowerCase();
            final primaryArtist = track.artists.split(',').first.trim().toLowerCase();
            final candidateArtist = (record['artistName'] as String? ?? '').toLowerCase();
            final artistMatches = candidateArtist == primaryArtist || candidateArtist.contains(primaryArtist);
            return titleMatches && artistMatches;
          });
          data = matching.cast<Map<String, dynamic>?>().firstWhere(
                (record) => ((record?['plainLyrics'] as String?)?.isNotEmpty ?? false) || ((record?['syncedLyrics'] as String?)?.isNotEmpty ?? false),
                orElse: () => null,
              );
        }
      } else {
        throw const LyricsUnavailableException('Não foi possível carregar a letra agora.');
      }

      if (data == null) {
        _cache[track.uri] = null;
        return null;
      }
      final synced = (data['syncedLyrics'] as String?)?.trim() ?? '';
      var text = '';
      if (synced.isNotEmpty) {
        // Keep timestamp-only lines as musical markers for instrumental breaks.
        text = synced
            .split('\n')
            .map((line) {
              final hasTimestamp = RegExp(r'^\s*\[[0-9:.]+\]').hasMatch(line);
              final lyric = line.replaceFirst(RegExp(r'^\s*\[[0-9:.]+\]\s*'), '').trim();
              if (lyric.isNotEmpty && !lyric.startsWith('[')) return lyric;
              return hasTimestamp ? '♪' : '';
            })
            .where((line) => line.isNotEmpty)
            .join('\n');
      } else {
        text = (data['plainLyrics'] as String?)?.trim() ?? '';
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
