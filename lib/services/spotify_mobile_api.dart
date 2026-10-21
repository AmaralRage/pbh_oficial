import 'dart:convert';

import 'package:http/http.dart' as http;

/// Spotify Connect transport. Tokens remain in memory for this app session.
class SpotifyMobileApi {
  SpotifyMobileApi({required this.clientId, http.Client? client})
    : _client = client ?? http.Client();

  final String clientId;
  final http.Client _client;
  String? _accessToken;
  String? _refreshToken;
  DateTime _expiresAt = DateTime(1970);
  DateTime? _retryAt;
  Future<void>? _refreshing;
  int _generation = 0;

  bool get isAuthenticated => _refreshToken != null;

  Future<void> authorize(String code, String verifier, String redirectUri) =>
      _token({
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': verifier,
        'redirect_uri': redirectUri,
      });

  Future<void> _token(Map<String, String> body) async {
    final generation = _generation;
    final response = await _client
        .post(
          Uri.https('accounts.spotify.com', '/api/token'),
          body: {'client_id': clientId, ...body},
        )
        .timeout(const Duration(seconds: 20));
    if (generation != _generation) throw StateError('Conexão encerrada.');
    if (response.statusCode != 200) {
      if (response.statusCode == 400 || response.statusCode == 401) clear();
      throw const SpotifyMobileException(
        'A sessão do Spotify expirou. Conecte novamente.',
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = data['access_token'] as String;
    _refreshToken = data['refresh_token'] as String? ?? _refreshToken;
    _expiresAt = DateTime.now().add(
      Duration(seconds: (data['expires_in'] as num).toInt()),
    );
  }

  Future<void> _refresh() async {
    if (_refreshing != null) return _refreshing;
    final token = _refreshToken;
    if (token == null) {
      throw const SpotifyMobileException('Conecte sua conta Spotify.');
    }
    final operation = _token({
      'grant_type': 'refresh_token',
      'refresh_token': token,
    });
    _refreshing = operation;
    try {
      await operation;
    } finally {
      if (identical(_refreshing, operation)) _refreshing = null;
    }
  }

  Future<Map<String, dynamic>?> request(
    String path, {
    String method = 'GET',
    Map<String, String> query = const {},
    Map<String, dynamic>? body,
  }) async {
    final generation = _generation;
    final retryAt = _retryAt;
    if (retryAt != null && DateTime.now().isBefore(retryAt)) {
      throw const SpotifyMobileException(
        'O Spotify limitou as consultas. Aguarde alguns instantes.',
      );
    }
    if (_accessToken == null ||
        DateTime.now().isAfter(
          _expiresAt.subtract(const Duration(seconds: 60)),
        )) {
      await _refresh();
    }
    for (var attempt = 0; attempt < 2; attempt++) {
      if (generation != _generation) throw StateError('Conexão encerrada.');
      final request = http.Request(
        method,
        Uri.https('api.spotify.com', '/v1$path', query),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      });
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(const Duration(seconds: 15)),
      ).timeout(const Duration(seconds: 15));
      if (generation != _generation) throw StateError('Conexão encerrada.');
      if (response.statusCode == 401 && attempt == 0) {
        await _refresh();
        continue;
      }
      if (response.statusCode == 204) return null;
      if (response.statusCode == 429) {
        _retryAt = DateTime.now().add(
          Duration(
            seconds: int.tryParse(response.headers['retry-after'] ?? '') ?? 30,
          ),
        );
        throw const SpotifyMobileException(
          'O Spotify limitou as consultas. Aguarde alguns instantes.',
        );
      }
      if (response.statusCode >= 400) {
        if (response.statusCode == 401) clear();
        final message = switch (response.statusCode) {
          401 => 'A sessão do Spotify expirou. Conecte novamente.',
          403 =>
            'O Spotify negou este acesso. Verifique a conta Premium, os usuários autorizados e as permissões da playlist (HTTP 403).',
          404 =>
            'Abra o Spotify neste celular, inicie uma música e volte ao PBH.',
          _ =>
            'O Spotify não respondeu ao comando (HTTP ${response.statusCode}). Tente novamente.',
        };
        throw SpotifyMobileException(message);
      }
      return response.body.isEmpty
          ? null
          : jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw const SpotifyMobileException('Conecte novamente ao Spotify.');
  }

  void clear() {
    _generation++;
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = DateTime(1970);
    _retryAt = null;
    _refreshing = null;
  }
}

class SpotifyMobileException implements Exception {
  const SpotifyMobileException(this.message);
  final String message;
  @override
  String toString() => message;
}
