import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pbh_oficial/services/spotify_mobile_api.dart';

http.Response token({String access = 'access', int expires = 3600}) =>
    http.Response(
      jsonEncode({
        'access_token': access,
        'refresh_token': 'refresh',
        'expires_in': expires,
      }),
      200,
    );

void main() {
  test(
    'PKCE exchange sends verifier without client secret and authenticates API calls',
    () async {
      final api = SpotifyMobileApi(
        clientId: 'public-id',
        client: MockClient((request) async {
          if (request.url.path == '/api/token') {
            expect(request.bodyFields, {
              'client_id': 'public-id',
              'grant_type': 'authorization_code',
              'code': 'code',
              'code_verifier': 'verifier',
              'redirect_uri': 'pbh-oficial://spotify-callback',
            });
            return token();
          }
          expect(request.headers['Authorization'], 'Bearer access');
          return http.Response('', 204);
        }),
      );
      await api.authorize('code', 'verifier', 'pbh-oficial://spotify-callback');
      expect(api.isAuthenticated, isTrue);
      expect(await api.request('/me/player'), isNull);
    },
  );

  test('concurrent requests share a single token refresh', () async {
    var tokenRequests = 0;
    final refresh = Completer<http.Response>();
    final api = SpotifyMobileApi(
      clientId: 'id',
      client: MockClient((request) async {
        if (request.url.path == '/api/token') {
          tokenRequests++;
          if (tokenRequests == 1) return token(expires: 0);
          expect(request.bodyFields['grant_type'], 'refresh_token');
          return refresh.future;
        }
        expect(request.headers['Authorization'], 'Bearer renewed');
        return http.Response('{}', 200);
      }),
    );
    await api.authorize('code', 'verifier', 'redirect');
    final first = api.request('/me/player');
    final second = api.request('/me/player/devices');
    refresh.complete(token(access: 'renewed'));
    await Future.wait([first, second]);
    expect(tokenRequests, 2);
  });

  test('401 refreshes once and retries the authorized request', () async {
    var tokens = 0;
    var requests = 0;
    final api = SpotifyMobileApi(
      clientId: 'id',
      client: MockClient((request) async {
        if (request.url.path == '/api/token') {
          return token(access: 'token-${++tokens}');
        }
        requests++;
        if (requests == 1) return http.Response('{}', 401);
        expect(request.headers['Authorization'], 'Bearer token-2');
        return http.Response('{"is_playing":true}', 200);
      }),
    );
    await api.authorize('code', 'verifier', 'redirect');
    expect((await api.request('/me/player'))?['is_playing'], isTrue);
    expect(requests, 2);
    expect(tokens, 2);
  });

  test('rate limiting prevents polling during Retry-After', () async {
    var requests = 0;
    final api = SpotifyMobileApi(
      clientId: 'id',
      client: MockClient((request) async {
        if (request.url.path == '/api/token') return token();
        requests++;
        return http.Response('{}', 429, headers: {'retry-after': '60'});
      }),
    );
    await api.authorize('code', 'verifier', 'redirect');
    await expectLater(
      api.request('/me/player'),
      throwsA(isA<SpotifyMobileException>()),
    );
    await expectLater(
      api.request('/me/player'),
      throwsA(isA<SpotifyMobileException>()),
    );
    expect(requests, 1);
  });

  test('disconnect invalidates a pending authorization response', () async {
    final response = Completer<http.Response>();
    final api = SpotifyMobileApi(
      clientId: 'id',
      client: MockClient((_) => response.future),
    );
    final authorization = api.authorize('code', 'verifier', 'redirect');
    final rejected = expectLater(authorization, throwsStateError);
    api.clear();
    response.complete(token());
    await rejected;
    expect(api.isAuthenticated, isFalse);
  });
}
