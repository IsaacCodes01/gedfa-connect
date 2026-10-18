import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// A passport photo ready to upload: a 300×400 photo and a 96×128
/// thumbnail, both JPEG.
class ProcessedPhoto {
  const ProcessedPhoto({required this.full, required this.thumb});

  final Uint8List full;
  final Uint8List thumb;
}

/// Turns any picked image into a passport photo:
/// 1. turns it the right way up (phone photos often store a rotation flag)
/// 2. cuts the middle into a 3:4 portrait
/// 3. shrinks it to 300×400 (photo) and 96×128 (thumbnail)
/// 4. saves both as JPEG
///
/// Returns null if the file isn't an image we can read.
ProcessedPhoto? makePassportPhoto(Uint8List source) {
  final decoded = img.decodeImage(source);
  if (decoded == null) return null;

  final upright = img.bakeOrientation(decoded);

  // Largest 3:4 portrait that fits, taken from the centre
  final width = upright.width;
  final height = upright.height;
  var cropWidth = width;
  var cropHeight = (width * 4 / 3).round();
  if (cropHeight > height) {
    cropHeight = height;
    cropWidth = (height * 3 / 4).round();
  }
  final cropped = img.copyCrop(
    upright,
    x: ((width - cropWidth) / 2).round(),
    y: ((height - cropHeight) / 2).round(),
    width: cropWidth,
    height: cropHeight,
  );

  final full = img.copyResize(
    cropped,
    width: 300,
    height: 400,
    interpolation: img.Interpolation.average,
  );
  final thumb = img.copyResize(
    cropped,
    width: 96,
    height: 128,
    interpolation: img.Interpolation.average,
  );

  return ProcessedPhoto(
    full: img.encodeJpg(full, quality: 85),
    thumb: img.encodeJpg(thumb, quality: 80),
  );
}
