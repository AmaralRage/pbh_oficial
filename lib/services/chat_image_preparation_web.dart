import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<Uint8List> prepareBrowserChatImage(Uint8List bytes) async {
  final blob = web.Blob([bytes.toJS].toJS);
  final bitmap = await web.window.createImageBitmap(blob).toDart;
  final canvas = web.HTMLCanvasElement();
  try {
    for (final side in [1280, 1024, 768, 512]) {
      final scale = math.min(1.0, side / math.max(bitmap.width, bitmap.height));
      canvas.width = math.max(1, (bitmap.width * scale).round());
      canvas.height = math.max(1, (bitmap.height * scale).round());
      final context = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      context.fillStyle = '#ffffff'.toJS;
      context.fillRect(0, 0, canvas.width.toDouble(), canvas.height.toDouble());
      context.drawImage(
        bitmap,
        0,
        0,
        canvas.width.toDouble(),
        canvas.height.toDouble(),
      );
      final encoded = Completer<web.Blob>();
      canvas.toBlob(
        ((web.Blob? result) {
          if (result == null) {
            encoded.completeError(
              StateError('Não foi possível preparar a foto.'),
            );
          } else {
            encoded.complete(result);
          }
        }).toJS,
        'image/jpeg',
        (side >= 1024 ? .78 : .65).toJS,
      );
      final jpeg = await encoded.future;
      if (jpeg.size <= 512 * 1024) {
        return (await jpeg.arrayBuffer().toDart).toDart.asUint8List();
      }
    }
    throw ArgumentError('A foto continua muito grande. Escolha outra imagem.');
  } finally {
    bitmap.close();
    canvas.width = 1;
    canvas.height = 1;
  }
}
