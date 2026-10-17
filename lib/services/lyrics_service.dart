import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/spotify_track.dart';

class LyricLine {
  const LyricLine({required this.text, this.timestamp});

  final String text;
  final Duration? timestamp;
}

class LyricsDocument {
  const LyricsDocument({required this.lines, required this.isSynced});

  final List<LyricLine> lines;
  final bool isSynced;

  String get plainText => lines.map((line) => line.text).join('\n');
}

class LyricsService {
  LyricsService._();

  static final LyricsService instance = LyricsService._();
  final http.Client _client = http.Client();
  final Map<String, LyricsDocument?> _cache = {};

  Future<LyricsDocument?> lyricsFor(SpotifyTrack track, Duration duration) async {
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
        throw const LyricsUnavailableException('Muitas consultas de letras em sequÃªncia. Tente novamente em instantes.');
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
          throw const LyricsUnavailableException('Muitas consultas de letras em sequÃªncia. Tente novamente em instantes.');
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
        throw const LyricsUnavailableException('NÃ£o foi possÃ­vel carregar a letra agora.');
      }

      if (data == null) {
        _cache[track.uri] = null;
        return null;
      }

      final synced = (data['syncedLyrics'] as String?)?.trim() ?? '';
      final syncedLines = _parseSyncedLyrics(synced);
      final lines = syncedLines.isNotEmpty
          ? syncedLines
          : ((data['plainLyrics'] as String?) ?? '')
              .split('\n')
              .map((line) => LyricLine(text: line.trim()))
              .where((line) => line.text.isNotEmpty)
              .toList();
      final document = lines.isEmpty
          ? null
          : LyricsDocument(lines: lines, isSynced: syncedLines.isNotEmpty);
      _cache[track.uri] = document;
      return document;
    } on LyricsUnavailableException {
      rethrow;
    } catch (_) {
      throw const LyricsUnavailableException('Sem conexÃ£o para carregar as letras.');
    }
  }

  List<LyricLine> _parseSyncedLyrics(String source) {
    final timestampPattern = RegExp(r'\[(\d+):(\d{2})(?:[.:](\d{1,3}))?\]');
    final lines = <LyricLine>[];

    for (final rawLine in source.split('\n')) {
      final timestamps = timestampPattern.allMatches(rawLine).toList();
      if (timestamps.isEmpty) continue;

      final text = rawLine.replaceAll(timestampPattern, '').trim();
      final lineText = text.isEmpty ? '\u266a' : text;
      for (final timestamp in timestamps) {
        final minutes = int.parse(timestamp.group(1)!);
        final seconds = int.parse(timestamp.group(2)!);
        final fraction = (timestamp.group(3) ?? '').padRight(3, '0');
        final milliseconds = fraction.isEmpty ? 0 : int.parse(fraction);
        lines.add(LyricLine(
          text: lineText,
          timestamp: Duration(
            minutes: minutes,
            seconds: seconds,
            milliseconds: milliseconds,
          ),
        ));
      }
    }

    lines.sort((a, b) => a.timestamp!.compareTo(b.timestamp!));
    return lines;
  }
}

class LyricsUnavailableException implements Exception {
  const LyricsUnavailableException(this.message);
  final String message;
}
