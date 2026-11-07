import 'dart:async';
import 'dart:typed_data';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

bool get photoDownloadSupported => true;

Future<bool> savePhotoBytes(Uint8List bytes, String name, String mime) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = name;
  try {
    web.document.body?.appendChild(anchor);
    anchor.click();
  } finally {
    anchor.remove();
    Timer(const Duration(seconds: 30), () => web.URL.revokeObjectURL(url));
  }
  return true;
}
