import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flexcrew/core/config.dart';

/// Resize/encode images to reasonable mobile-friendly sizes before upload.
/// Returns JPG bytes (for simplicity) unless the input was PNG and requested to keep png.
Future<Uint8List> resizeImage(Uint8List inputBytes,
    {int? maxDimension, int? jpgQuality, bool preservePng = false}) async {
  final image = img.decodeImage(inputBytes);
  if (image == null) return inputBytes;

  maxDimension ??= AppConfig.avatarMaxDimension;
  jpgQuality ??= AppConfig.avatarJpgQuality;

  // If already smaller than maxDimension, keep original
  if (image.width <= maxDimension && image.height <= maxDimension) {
    return inputBytes;
  }

  final resized = img.copyResize(image, width: maxDimension);

  if (preservePng) {
    final encoded = img.encodePng(resized);
    return Uint8List.fromList(encoded);
  }

  final encoded = img.encodeJpg(resized, quality: jpgQuality);
  return Uint8List.fromList(encoded);
}

