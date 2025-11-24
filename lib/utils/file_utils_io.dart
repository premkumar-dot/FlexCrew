import 'dart:io';
import 'dart:typed_data';

/// IO implementation used on mobile/desktop to read bytes from a file path.
Future<Uint8List?> readFileBytes(String? path) async {
  if (path == null) return null;
  try {
    final f = File(path);
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

