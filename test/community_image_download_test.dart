import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pbh_oficial/services/community_image_download.dart';

void main() {
  final original = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
  );
  test(
    'download saves exact original bytes with detected image type',
    () async {
      Uint8List? saved;
      final client = MockClient(
        (request) async => http.Response.bytes(original, 200),
      );
      addTearDown(client.close);
      final download = CommunityImageDownload(
        client: client,
        save: (bytes, name, mime) async {
          saved = bytes;
          expect(name, endsWith('.png'));
          expect(mime, 'image/png');
          return true;
        },
      );
      expect(
        await download.download(
          'https://example.invalid/original.png?token=fixture',
        ),
        true,
      );
      expect(saved, original);
    },
  );
  test('expired URLs and non-images never reach device storage', () async {
    for (final status in [403, 200]) {
      final client = MockClient(
        (_) async => http.Response('<html>not a photo</html>', status),
      );
      addTearDown(client.close);
      final download = CommunityImageDownload(
        client: client,
        save: (_, __, ___) async {
          fail('Invalid data saved');
        },
      );
      await expectLater(
        download.download('https://example.invalid/photo.png'),
        throwsA(anything),
      );
    }
  });
  test('canceling the save picker does not report success', () async {
    final client = MockClient((_) async => http.Response.bytes(original, 200));
    addTearDown(client.close);
    expect(
      await CommunityImageDownload(
        client: client,
        save: (_, __, ___) async => false,
      ).download('https://example.invalid/photo.png'),
      false,
    );
  });
}
