import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

Future<Uint8List> prepareChatImage(Uint8List bytes) =>
    compute(compressChatImage, bytes);
Uint8List compressChatImage(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > 15 * 1024 * 1024)
    throw ArgumentError('Escolha uma foto de até 15 MB.');
  final decoder = img.findDecoderForData(bytes),
      info = decoder?.startDecode(bytes);
  if (decoder == null ||
      info == null ||
      info.numFrames != 1 ||
      info.width * info.height > 32000000)
    throw ArgumentError('Escolha uma foto estática de até 32 megapixels.');
  final source = decoder.decodeFrame(0);
  if (source == null) throw ArgumentError('Não foi possível abrir esta foto.');
  var image = img.bakeOrientation(source);
  image.exif = img.ExifData();
  for (final side in [1280, 1024, 768, 512]) {
    if (image.width > side || image.height > side)
      image = img.copyResize(
        image,
        width: image.width >= image.height ? side : null,
        height: image.height > image.width ? side : null,
      );
    final result = Uint8List.fromList(
      img.encodeJpg(image, quality: side >= 1024 ? 78 : 65),
    );
    if (result.length <= 512 * 1024) return result;
  }
  throw ArgumentError('A foto continua muito grande. Escolha outra imagem.');
}
