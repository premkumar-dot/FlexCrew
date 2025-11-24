import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  StorageService._();
  static final instance = StorageService._();

  final _storage = FirebaseStorage.instance;

  /// Uploads bytes as avatars/{uid}/avatar_<timestamp>.ext, returns a public download URL.
  Future<String> uploadAvatar({
    required String uid,
    required Uint8List bytes,
    required String contentType, // e.g. "image/jpeg" | "image/png"
  }) async {
    String ext;
    switch (contentType) {
      case 'image/png':
        ext = 'png';
        break;
      case 'image/webp':
        ext = 'webp';
        break;
      case 'image/jpeg':
      default:
        ext = 'jpg';
    }

    final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('avatars/$uid/$filename');

    final task = ref.putData(bytes, SettableMetadata(contentType: contentType));
    await task;
    return await ref.getDownloadURL();
  }

  /// Upload with progress callback (0.0 - 1.0) and return the download URL.
  Future<String> uploadAvatarWithProgress({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    required void Function(double progress) onProgress,
  }) async {
    print('[StorageService] uploadAvatarWithProgress START: uid=$uid, size=${bytes.length}, contentType=$contentType');
    
    String ext;
    switch (contentType) {
      case 'image/png':
        ext = 'png';
        break;
      case 'image/webp':
        ext = 'webp';
        break;
      case 'image/jpeg':
      default:
        ext = 'jpg';
    }

    final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('avatars/$uid/$filename');
    print('[StorageService] Starting upload to: avatars/$uid/$filename');

    final uploadTask =
        ref.putData(bytes, SettableMetadata(contentType: contentType));
    print('[StorageService] putData called, now listening to progress...');

    // Listen to progress
    final sub = uploadTask.snapshotEvents.listen((snapshot) {
      final total = snapshot.totalBytes;
      final transferred = snapshot.bytesTransferred;
      print('[StorageService] Progress: $transferred / $total bytes');
      if (total > 0) {
        final progress = transferred / total;
        try {
          onProgress(progress);
        } catch (e) {
          print('[StorageService] Error calling onProgress: $e');
        }
      }
    });

    print('[StorageService] Waiting for upload task to complete...');
    await uploadTask.whenComplete(() async {
      print('[StorageService] Upload task completed, cancelling subscription');
      await sub.cancel();
    });

    print('[StorageService] Getting download URL...');
    final url = await ref.getDownloadURL();
    print('[StorageService] Got download URL: $url');
    
    return url;
  }

  /// Delete avatar files under `avatars/{uid}/`.
  /// If [excludeDownloadUrl] is provided, that file is preserved.
  /// Best-effort cleanup; errors are ignored.
  Future<void> deleteAllAvatarsExcept(
    String uid, {
    String? excludeDownloadUrl,
  }) async {
    String? excludePath;
    if (excludeDownloadUrl != null && excludeDownloadUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(excludeDownloadUrl);
        final segments = uri.pathSegments;
        final oIndex = segments.indexOf('o');
        if (oIndex != -1 && oIndex + 1 < segments.length) {
          excludePath = Uri.decodeComponent(segments[oIndex + 1]);
        }
      } catch (_) {
        excludePath = null;
      }
    }

    try {
      final listRef = _storage.ref().child('avatars/$uid');
      final listResult = await listRef.listAll();
      final futures = <Future<void>>[];
      for (final item in listResult.items) {
        if (excludePath != null && item.fullPath == excludePath) continue;
        futures.add(item.delete().catchError((_) {}));
      }
      await Future.wait(futures);
    } catch (_) {
      // ignore cleanup errors
    }
  }

  /// Helper: returns a storage path for worker documents.
  /// Example: workerDocs/{uid}/{fileName}
  String pathForWorkerDoc(String uid, String fileName) {
    return 'workerDocs/$uid/$fileName';
  }

  /// Upload arbitrary bytes to the given storage path and return download URL.
  /// If [onProgress] is provided it receives values 0.0-1.0.
  Future<String> uploadBytes({
    required String path,
    required Uint8List data,
    String? contentType,
    void Function(double progress)? onProgress,
  }) async {
    final ref = _storage.ref().child(path);
    final metadata = contentType != null
        ? SettableMetadata(contentType: contentType)
        : null;
    final uploadTask = metadata != null
        ? ref.putData(data, metadata)
        : ref.putData(data);

    if (onProgress != null) {
      final sub = uploadTask.snapshotEvents.listen((snapshot) {
        final total = snapshot.totalBytes;
        final transferred = snapshot.bytesTransferred;
        if (total > 0) onProgress(transferred / total);
      });
      await uploadTask.whenComplete(() async {
        await sub.cancel();
      });
    } else {
      await uploadTask;
    }

    return await ref.getDownloadURL();
  }
}

