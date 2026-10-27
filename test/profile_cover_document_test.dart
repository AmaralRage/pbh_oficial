import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pbh_oficial/services/profile_cover_document.dart';
import 'package:pbh_oficial/services/profile_customization_service.dart';

void main() {
  test('GIF and HTML are covers, while avatars retain their image policy', () {
    final gif = Uint8List.fromList(ascii.encode('GIF89a'));
    final html = Uint8List.fromList(
      utf8.encode('<!doctype html><html><body>Arte</body></html>'),
    );
    expect(ProfileCustomizationService.coverType(gif), 'gif');
    expect(ProfileCustomizationService.coverType(html), 'html');
    expect(
      () => ProfileCustomizationService.imageType(gif),
      throwsArgumentError,
    );
    expect(
      () => ProfileCustomizationService.imageType(html),
      throwsArgumentError,
    );
    expect(
      () => ProfileCoverDocument.decode(Uint8List.fromList([...html, 255])),
      throwsArgumentError,
    );
    expect(
      () => ProfileCustomizationService.coverType(
        Uint8List(ProfileCoverDocument.maxBytes + 1),
      ),
      throwsArgumentError,
    );
    expect(
      ProfileCoverDocument.isHtmlUrl('https://example.com/art.HTML?x=1'),
      isTrue,
    );
    expect(
      ProfileCoverDocument.isHtmlUrl('https://example.com/art.png'),
      isFalse,
    );
  });

  test(
    'untrusted markup stays inside a restricted iframe, preserving embedded styles',
    () {
      final source =
          '''<!doctype html><html><head><style>.cover{background:#123456}</style></head><body><div class="cover"><canvas></canvas></div><script>requestAnimationFrame(()=>{document.body.dataset.painted='yes'})</script></body></html>''';
      final wrapped = ProfileCoverDocument.wrap(
        source,
        playing: false,
        reducedMotion: false,
      );
      expect(wrapped, contains('sandbox="allow-scripts"'));
      expect(wrapped, isNot(contains('allow-same-origin')));
      expect(wrapped, contains("connect-src 'none'"));
      expect(wrapped, contains('form-action'));
      expect(wrapped, contains('document.head.append(style)'));
      expect(wrapped, contains('&lt;canvas&gt;'));
      expect(wrapped, isNot(contains('<canvas>')));
      final reduced = ProfileCoverDocument.wrap(
        source,
        playing: false,
        reducedMotion: true,
      );
      expect(reduced, contains('animation:none!important'));
      // Local browser fixture: color + JS paint must survive the nested sandbox.
      final directory = Directory('build')..createSync(recursive: true);
      File(
        '${directory.path}/html-cover-sandbox-preview.html',
      ).writeAsStringSync(wrapped);
    },
  );
}
