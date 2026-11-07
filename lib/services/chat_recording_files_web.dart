import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<String> recordingPath(String id, String format) async => '';
Future<Uint8List> readRecording(String path) async {
  if (!path.startsWith('blob:')) throw StateError('Gravação indisponível.');
  try {
    final response = await web.window.fetch(path.toJS).toDart;
    final blob = await response.blob().toDart;
    if (blob.size > 1048576)
      throw StateError('Áudio muito grande. Grave uma mensagem menor.');
    return (await blob.arrayBuffer().toDart).toDart.asUint8List();
  } finally {
    web.URL.revokeObjectURL(path);
  }
}
