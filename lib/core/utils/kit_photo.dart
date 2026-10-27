import 'dart:typed_data';

import 'package:gedfa_connect/features/teams/domain/kit_photos.dart';
import 'package:image/image.dart' as img;

/// Gets a kit photo ready to upload (2.13b), like the passport photo:
/// 1. turns it the right way up
/// 2. cuts the middle to the part's shape (shirt square, shorts wide,
///    socks tall)
/// 3. shrinks it (shirt 600×600, shorts 600×360, socks 360×600)
/// 4. saves it as JPEG
///
/// Returns null if the file isn't an image we can read.
Uint8List? makeKitPhoto(Uint8List source, KitPart part) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;

  final upright = img.bakeOrientation(decoded);

  // The largest box with the part's shape that fits, from the centre
  final width = upright.width;
  final height = upright.height;
  var cropWidth = width;
  var cropHeight = (width / part.aspect).round();
  if (cropHeight > height) {
    cropHeight = height;
    cropWidth = (height * part.aspect).round();
  }
  final cropped = img.copyCrop(
    upright,
    x: ((width - cropWidth) / 2).round(),
    y: ((height - cropHeight) / 2).round(),
    width: cropWidth,
    height: cropHeight,
  );

  final resized = img.copyResize(
    cropped,
    width: part.width,
    height: part.height,
    interpolation: img.Interpolation.average,
  );
  return img.encodeJpg(resized, quality: 82);
}
