import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';

bool get photoDownloadSupported =>
    Platform.isAndroid ||
    Platform.isWindows ||
    Platform.isLinux ||
    Platform.isMacOS;

Future<bool> savePhotoBytes(Uint8List bytes, String name, String mime) async {
  if (Platform.isAndroid) {
    return await const MethodChannel('pbh/photo_download').invokeMethod<bool>(
          'save',
          {'bytes': bytes, 'name': name, 'mime': mime},
        ) ??
        false;
  }
  final location = await getSaveLocation(suggestedName: name);
  if (location == null) return false;
  await XFile.fromData(bytes, name: name, mimeType: mime).saveTo(location.path);
  return true;
}
