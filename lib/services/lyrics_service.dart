import 'dart:async';
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
  Future<void> _requestQueue = Future<void>.value();
  DateTime? _lastRequestAt;

  Future<http.Response> _get(Uri uri) {
    final completer = Completer<http.Response>();
    _requestQueue = _requestQueue.then((_) async {
      try {
        completer.complete(await _getWithRetry(uri));
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<http.Response> _getWithRetry(Uri uri) async {
    var retryCount = 0;
    while (true) {
      final lastRequestAt = _lastRequestAt;
      if (lastRequestAt != null) {
        final remaining = const Duration(milliseconds: 300) - DateTime.now().difference(lastRequestAt);
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      }

      http.Response response;
      try {
        response = await _client.get(uri, headers: const {
          'X-User-Agent': 'PBH Oficial/1.0 (https://pbh-oficial.vercel.app)',
        }).timeout(const Duration(seconds: 12));
      } catch (_) {
        _lastRequestAt = DateTime.now();
        if (retryCount++ == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        throw const LyricsUnavailableException('O serviço de letras está temporariamente indisponível. Tente novamente.');
      }
      _lastRequestAt = DateTime.now();

      if (response.statusCode == 429) {
        final retryAfter = int.tryParse(response.headers['retry-after'] ?? '');
        if (retryCount == 0 && retryAfter != null && retryAfter <= 5) {
          retryCount++;
          await Future<void>.delayed(Duration(seconds: retryAfter));
          continue;
        }
        final waitMessage = retryAfter == null
            ? ' Tente novamente em instantes.'
            : ' Aguarde $retryAfter segundos e tente novamente.';
        throw LyricsUnavailableException('O serviço de letras limitou as consultas.$waitMessage');
      }

      if (response.statusCode >= 500 && retryCount++ == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        continue;
      }
      return response;
    }
  }

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
      final response = await _get(uri);
      Map<String, dynamic>? data;
      if (response.statusCode == 200) {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 404) {
        final searchUri = Uri.https('lrclib.net', '/api/search', {
          'track_name': track.name,
          'artist_name': track.artists.split(',').first.trim(),
        });
        final searchResponse = await _get(searchUri);
        if (searchResponse.statusCode == 200) {
          final records = jsonDecode(searchResponse.body) as List<dynamic>;
          final primaryArtist = _normalize(track.artists.split(',').first);
          final title = _normalize(track.name);
          final matching = records.whereType<Map<String, dynamic>>().where((record) {
            final candidateTitle = _normalize(record['trackName'] as String? ?? '');
            final candidateArtist = _normalize(record['artistName'] as String? ?? '');
            final hasLyrics = ((record['plainLyrics'] as String?)?.trim().isNotEmpty ?? false) ||
                ((record['syncedLyrics'] as String?)?.trim().isNotEmpty ?? false);
            return candidateTitle == title &&
                candidateArtist.contains(primaryArtist) &&
                hasLyrics &&
                _durationMatches(record, duration);
          }).toList();
          matching.sort((first, second) => _durationDifference(first, duration).compareTo(_durationDifference(second, duration)));
          if (matching.isNotEmpty) data = matching.first;
        } else {
          throw const LyricsUnavailableException('O serviço de letras não respondeu corretamente. Tente novamente.');
        }
      } else {
        throw const LyricsUnavailableException('O serviço de letras não respondeu corretamente. Tente novamente.');
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
      throw const LyricsUnavailableException('Não foi possível carregar as letras. Verifique a conexão e tente novamente.');
    }
  }

  String _normalize(String value) {
    var normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp('[áàâãäå]'), 'a')
        .replaceAll(RegExp('[éèêë]'), 'e')
        .replaceAll(RegExp('[íìîï]'), 'i')
        .replaceAll(RegExp('[óòôõö]'), 'o')
        .replaceAll(RegExp('[úùûü]'), 'u')
        .replaceAll('ç', 'c')
        .replaceAll('ñ', 'n');
    if (normalized.runes.any((rune) => rune > 127)) {
      return normalized.replaceAll(RegExp(r'\s+'), ' ');
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  bool _durationMatches(Map<String, dynamic> record, Duration duration) {
    final seconds = (record['duration'] as num?)?.toDouble();
    if (seconds == null || duration <= Duration.zero) return true;
    return (seconds - duration.inMilliseconds / 1000).abs() <= 8;
  }

  double _durationDifference(Map<String, dynamic> record, Duration duration) {
    final seconds = (record['duration'] as num?)?.toDouble();
    if (seconds == null || duration <= Duration.zero) return double.infinity;
    return (seconds - duration.inMilliseconds / 1000).abs();
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
