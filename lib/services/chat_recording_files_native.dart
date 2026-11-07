import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> recordingPath(String id, String format) async =>
    '${(await getTemporaryDirectory()).path}/pbh-voice-$id.$format';
Future<Uint8List> readRecording(String path) async {
  final file = File(path);
  try {
    if (await file.length() > 1048576)
      throw StateError('Áudio muito grande. Grave uma mensagem menor.');
    return await file.readAsBytes();
  } finally {
    if (await file.exists()) await file.delete();
  }
}
