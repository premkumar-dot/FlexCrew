import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// Circle avatar that shows user's photo or initials.
/// Tap uploads a new photo to Storage + saves URL in Auth + Firestore.
class UserAvatar extends StatefulWidget {
  const UserAvatar({
    super.key,
    this.radius = 18,
    this.enableUpload = true,
    this.onChanged,
  });

  final double radius;
  final bool enableUpload;
  final VoidCallback? onChanged;

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _busy = false;

  String _initials(User? u, Map<String, dynamic>? profile) {
    final name = (profile?['fullName'] ?? u?.displayName ?? u?.email ?? '')
        .toString()
        .trim();
    if (name.isEmpty) return '?';
    final parts =
        name.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final one = parts.first[0];
    final two = parts.length > 1 ? parts.last[0] : '';
    return (one + two).toUpperCase();
  }

  Future<void> _pickAndUpload() async {
    if (!widget.enableUpload) return;
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.single;
    final Uint8List? bytes = file.bytes;
    if (bytes == null) return;

    final ext = (file.extension ?? 'jpg').toLowerCase();
    final path = 'profiles/${u.uid}/avatar/avatar.$ext';

    setState(() => _busy = true);
    try {
      final ref = FirebaseStorage.instance.ref(path);
      final snap = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$ext'),
      );
      final url = await snap.ref.getDownloadURL();

      await u.updatePhotoURL(url);
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated')),
      );
      setState(() {}); // refresh
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) {
      return CircleAvatar(
        radius: widget.radius,
        child: const Icon(Icons.person_outline),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance.collection('users').doc(u.uid).snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final photo = (data?['photoUrl'] ?? u.photoURL) as String?;
        final initials = _initials(u, data);

        final avatar = (photo != null && photo.isNotEmpty)
            ? CircleAvatar(
                radius: widget.radius, backgroundImage: NetworkImage(photo))
            : CircleAvatar(radius: widget.radius, child: Text(initials));

        return Stack(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(widget.radius),
              onTap: _pickAndUpload,
              child: avatar,
            ),
            if (_busy)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black26,
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

