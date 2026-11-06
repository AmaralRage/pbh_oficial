import 'dart:io';
import 'package:image/image.dart' as image;

void main() {
  final icon = image.Image(width: 192, height: 192, numChannels: 4);
  final orange = image.ColorRgba8(255, 107, 44, 255),
      white = image.ColorRgba8(255, 255, 255, 255);
  image.fillRect(
    icon,
    x1: 0,
    y1: 0,
    x2: 191,
    y2: 191,
    radius: 36,
    color: orange,
  );
  image.fillCircle(icon, x: 53, y: 70, radius: 17, color: white);
  image.fillCircle(icon, x: 139, y: 70, radius: 17, color: white);
  image.fillRect(
    icon,
    x1: 29,
    y1: 95,
    x2: 71,
    y2: 139,
    radius: 12,
    color: white,
  );
  image.fillRect(
    icon,
    x1: 121,
    y1: 95,
    x2: 163,
    y2: 139,
    radius: 12,
    color: white,
  );
  image.fillRect(
    icon,
    x1: 71,
    y1: 87,
    x2: 121,
    y2: 147,
    radius: 15,
    color: orange,
  );
  image.fillCircle(icon, x: 96, y: 60, radius: 20, color: white);
  image.fillRect(
    icon,
    x1: 77,
    y1: 91,
    x2: 115,
    y2: 143,
    radius: 12,
    color: white,
  );
  final bytes = image.encodePng(icon);
  for (final path in [
    'web/icons/community-192.png',
    'android/app/src/main/res/drawable/pbh_community_large.png',
  ]) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);
  }
}
