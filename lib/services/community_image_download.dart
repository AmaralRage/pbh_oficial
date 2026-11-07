import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/community_photo.dart';
import 'photo_download_platform.dart' as platform;

class CommunityImageDownload {
  CommunityImageDownload({
    http.Client? client,
    Future<bool> Function(Uint8List, String, String)? save,
  }) : _client = client,
       _save = save ?? platform.savePhotoBytes;
  final http.Client? _client;
  final Future<bool> Function(Uint8List, String, String) _save;
  static bool get supported => platform.photoDownloadSupported;

  Future<bool> download(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https')
      throw StateError('Foto indisponível. Recarregue os anexos.');
    final client = _client ?? http.Client();
    try {
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200 ||
          (response.contentLength ?? 0) > CommunityPhoto.maxGifBytes)
        throw StateError(
          'Não foi possível baixar a foto. Recarregue os anexos e tente novamente.',
        );
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 30),
      )) {
        if (bytes.length + chunk.length > CommunityPhoto.maxGifBytes)
          throw StateError('Foto acima do limite permitido.');
        bytes.add(chunk);
      }
      final photo = CommunityPhoto(bytes.takeBytes());
      if (!const ['jpg', 'png', 'webp', 'gif'].contains(photo.extension))
        throw StateError('Este anexo não é uma foto.');
      // Download original bytes: preview crops never modify the saved image.
      return await _save(
        photo.bytes,
        'pbh-foto-${DateTime.now().millisecondsSinceEpoch}.${photo.extension}',
        photo.mime,
      );
    } finally {
      if (_client == null) client.close();
    }
  }
}
