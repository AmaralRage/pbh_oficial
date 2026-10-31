import 'dart:typed_data';
import '../services/profile_cover_document.dart';

class CommunityPhoto {
  CommunityPhoto(this.bytes) : extension = detect(bytes);
  final Uint8List bytes;
  final String extension;
  bool get isVideo => extension == 'mp4' || extension == 'webm';
  String get mime => extension == 'jpg'
      ? 'image/jpeg'
      : extension == 'html'
      ? 'text/plain'
      : '${isVideo ? 'video' : 'image'}/$extension';
  static const maxBytes = 5 * 1024 * 1024;
  static const maxGifBytes = 10 * 1024 * 1024;
  static const maxVideoBytes = 25 * 1024 * 1024;
  static const maxCount = 4;
  static String detect(Uint8List b) {
    if (ProfileCoverDocument.looksLikeHtml(b)) {
      ProfileCoverDocument.decode(b);
      return 'html';
    }
    final header = String.fromCharCodes(b.take(64));
    final gif = header.startsWith('GIF87a') || header.startsWith('GIF89a');
    final mp4 =
        b.length >= 12 &&
        header.substring(4, 8) == 'ftyp' &&
        const [
          'isom',
          'iso2',
          'mp41',
          'mp42',
          'avc1',
          'M4V ',
          'dash',
        ].contains(header.substring(8, 12));
    final webm =
        b.length >= 4 &&
        b[0] == 0x1a &&
        b[1] == 0x45 &&
        b[2] == 0xdf &&
        b[3] == 0xa3 &&
        String.fromCharCodes(b.take(1024)).contains('webm');
    final limit = mp4 || webm
        ? maxVideoBytes
        : gif
        ? maxGifBytes
        : maxBytes;
    if (b.isEmpty || b.length > limit)
      throw ArgumentError('Limite: fotos 5 MB, GIFs 10 MB e vídeos 25 MB.');
    if (gif) return 'gif';
    if (mp4) return 'mp4';
    if (webm) return 'webm';
    if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255)
      return 'jpg';
    if (b.length >= 8 &&
        b[0] == 137 &&
        b[1] == 80 &&
        b[2] == 78 &&
        b[3] == 71 &&
        b[4] == 13 &&
        b[5] == 10 &&
        b[6] == 26 &&
        b[7] == 10)
      return 'png';
    if (b.length >= 12 &&
        String.fromCharCodes(b.take(4)) == 'RIFF' &&
        String.fromCharCodes(b.skip(8).take(4)) == 'WEBP')
      return 'webp';
    throw ArgumentError('Use JPG, PNG, WebP, GIF, MP4, WebM ou HTML completo.');
  }
}
