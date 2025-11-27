import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Storage helper and compatibility shim for legacy callers that expect
/// `storage_service.StorageService.instance.*` APIs.
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Map common content types to file extensions
  static const _extFromContentType = {
    'image/jpeg': 'jpg',
    'image/png': 'png',
    'image/webp': 'webp',
    'application/pdf': 'pdf',
  };

  String _extForContentType(String contentType) {
    return _extFromContentType[contentType] ?? contentType.split('/').lastWhere((_) => true, orElse: () => 'bin');
  }

  /// Upload avatar bytes to `avatars/{uid}/{generatedFilename}` with progress callback.
  /// After upload succeeds, updates FirebaseAuth.currentUser.photoURL and writes
  /// `users/{uid}.photoUrl` (merge).
  Future<String> uploadAvatarWithProgress({
    required String uid,
    required Uint8List bytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final ext = _extForContentType(contentType);
    final filename = 'avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ref = _storage.ref().child('avatars/$uid/$filename');
    final metadata = SettableMetadata(contentType: contentType);

    final uploadTask = ref.putData(bytes, metadata);

    StreamSubscription<TaskSnapshot>? sub;
    try {
      sub = uploadTask.snapshotEvents.listen((snap) {
        final total = snap.totalBytes;
        final transferred = snap.bytesTransferred;
        if (total != 0 && onProgress != null) {
          onProgress(transferred / total);
        }
      });

      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Best-effort: update auth user and users doc
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updatePhotoURL(downloadUrl);
          await user.reload();
        }
      } catch (e, st) {
        debugPrint('StorageService: failed to update auth photoURL: $e\n$st');
      }

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'photoUrl': downloadUrl}, SetOptions(merge: true));
      } catch (e, st) {
        debugPrint('StorageService: failed to update users doc photoUrl: $e\n$st');
      }

      return downloadUrl;
    } finally {
      await sub?.cancel();
    }
  }

  /// Upload bytes to an explicit storage path (relative to root) and return download URL.
  /// Example `path`: `workerDocs/{uid}/file.pdf` or `avatars/{uid}/file.png`
  Future<String> uploadBytes({
    required String path,
    required Uint8List data,
    required String contentType,
  }) async {
    final ref = _storage.ref().child(path);
    final metadata = SettableMetadata(contentType: contentType);
    final task = ref.putData(data, metadata);
    final snapshot = await task.whenComplete(() {});
    final url = await snapshot.ref.getDownloadURL();
    return url;
  }

  /// Helper to produce a canonical worker doc storage path for a file named by `name`.
  /// Example result: `workerDocs/{uid}/{encoded-name}`
  String pathForWorkerDoc(String uid, String name) {
    final safe = Uri.encodeComponent(name);
    return 'workerDocs/$uid/$safe';
  }

  /// Convenience wrapper kept for compatibility with callers that previously used
  /// a top-level upload function. Returns a download URL and also updates auth/users.
  Future<String> uploadAvatarAndSetProfile({
    required String uid,
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) =>
      uploadAvatarWithProgress(uid: uid, bytes: bytes, contentType: contentType, onProgress: null);

  Future<String> uploadUserDoc(String uid, String filename, Uint8List bytes, {required String contentType}) async {
    final path = 'workerDocs/$uid/$filename';
    final ref = _storage.ref(path);

    try {
      final metadata = SettableMetadata(contentType: contentType);
      final task = ref.putData(bytes, metadata);
      task.snapshotEvents.listen((s) {
        final transferred = s.bytesTransferred;
        final total = s.totalBytes ?? transferred;
        debugPrint('[Storage] Progress: $transferred / $total');
      });

      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();
      debugPrint('[Storage] Uploaded to $path -> $url');
      return url;
    } on FirebaseException catch (e) {
      debugPrint('[Storage] FirebaseException code=${e.code} message=${e.message}');
      if (e.code.contains('permission') || e.code.contains('unauth') || e.code == 'storage/unauthorized') {
        throw Exception('Upload blocked by security rules or unauthenticated. Check Storage Rules and auth state.');
      }
      rethrow;
    } catch (e, st) {
      debugPrint('[Storage] Unexpected error: $e\n$st');
      rethrow;
    }
  }
}

