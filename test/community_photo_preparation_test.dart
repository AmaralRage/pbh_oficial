import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image;
import 'package:pbh_oficial/services/community_photo_preparation.dart';

void main() {
  test('tall static photo keeps the entire aspect while reducing its size', () {
    final original = image.Image(width: 1000, height: 3000);
    final input = Uint8List.fromList(image.encodeJpg(original));
    final result = prepareStaticPhotoBytes(input);
    final decoded = image.decodeJpg(result)!;
    expect(decoded.height, 1600);
    expect(decoded.width, 533);
    expect(result.length, lessThan(input.length));
  });
  test('transparent PNG retains transparency after resize', () {
    final original = image.Image(width: 1700, height: 100, numChannels: 4);
    final result = prepareStaticPhotoBytes(
      Uint8List.fromList(image.encodePng(original)),
    );
    final decoded = image.decodePng(result)!;
    expect(decoded.width, 1600);
    expect(decoded.getPixel(0, 0).a, 0);
  });
  test('GIF bytes are preserved instead of being flattened', () {
    final bytes = base64Decode(
      'R0lGODlhAQABAIAAAAAAAP///ywAAAAAAQABAAACAUwAOw==',
    );
    expect(prepareStaticPhotoBytes(bytes), same(bytes));
  });
}
