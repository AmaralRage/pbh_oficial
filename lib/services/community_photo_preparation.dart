import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;
import '../models/community_photo.dart';

Future<CommunityPhoto> prepareCommunityPhoto(Uint8List bytes) async =>
    CommunityPhoto(await compute(prepareStaticPhotoBytes, bytes));

Uint8List prepareStaticPhotoBytes(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > CommunityPhoto.maxVideoBytes)
    throw ArgumentError('O limite por arquivo é de 25 MB.');
  final jpeg =
      bytes.length >= 3 &&
      bytes[0] == 255 &&
      bytes[1] == 216 &&
      bytes[2] == 255;
  final png =
      bytes.length >= 8 &&
      bytes[0] == 137 &&
      bytes[1] == 80 &&
      bytes[2] == 78 &&
      bytes[3] == 71;
  // Never flatten GIF, animated WebP, HTML or video into a still image.
  if (!jpeg && !png) {
    CommunityPhoto(bytes);
    return bytes;
  }
  final decoder = image.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null) throw ArgumentError('Não foi possível abrir a foto.');
  if (info.numFrames > 1) {
    CommunityPhoto(bytes);
    return bytes;
  }
  if (info.width * info.height > 32000000)
    throw ArgumentError('Escolha uma foto de até 32 megapixels.');
  if (bytes.length <= 1024 * 1024 && info.width <= 1600 && info.height <= 1600)
    return bytes;
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) throw ArgumentError('Não foi possível abrir a foto.');
  var output = image.bakeOrientation(decoded);
  if (output.width > 1600 || output.height > 1600)
    output = image.copyResize(
      output,
      width: output.width >= output.height ? 1600 : null,
      height: output.height > output.width ? 1600 : null,
    );
  output.exif = image.ExifData();
  final result = Uint8List.fromList(
    jpeg ? image.encodeJpg(output, quality: 82) : image.encodePng(output),
  );
  if (result.length > CommunityPhoto.maxBytes)
    throw ArgumentError(
      'A foto continua acima de 5 MB. Escolha uma versão menor.',
    );
  return result;
}
