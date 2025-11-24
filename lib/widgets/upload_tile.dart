import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:flutter/material.dart';
import 'package:flexcrew/services/storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UploadTile extends StatefulWidget {
  final String label; // e.g. "ID Front"
  final String fileName; // e.g. "idFront.jpg" or "resume.pdf"
  final String firestoreField; // e.g. "idFrontUrl"
  final void Function(String url)? onUrl;

  const UploadTile({
    super.key,
    required this.label,
    required this.fileName,
    required this.firestoreField,
    this.onUrl,
  });

  @override
  State<UploadTile> createState() => _UploadTileState();
}

class _UploadTileState extends State<UploadTile> {
  String? _url;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap =
        await FirebaseFirestore.instance.collection('workers').doc(uid).get();
    setState(() => _url = snap.data()?[widget.firestoreField] as String?);
  }

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _busy = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final path = StorageService.instance.pathForWorkerDoc(uid, widget.fileName);
      // Try to detect a sensible content type (e.g. image/jpeg, application/pdf)
      final ext = (file.extension ?? '').toLowerCase();
      String? contentType = lookupMimeType(widget.fileName) ?? lookupMimeType(file.name);
      // Fallbacks for common extensions
      contentType ??= switch (ext) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'pdf' => 'application/pdf',
        _ => null,
      };

      final url = await StorageService.instance.uploadBytes(
        path: path,
        data: bytes,
        contentType: contentType,
      );
      await FirebaseFirestore.instance
          .collection('workers')
          .doc(uid)
          .set({widget.firestoreField: url}, SetOptions(merge: true));
      setState(() => _url = url);
      // Notify parent caller (e.g. onboarding screen) of new URL
      try {
        widget.onUrl?.call(url);
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.label} uploaded.'),
            backgroundColor: const Color(0xFFFF6A00), // Orange
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.grey[800],
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.label),
      subtitle: _url == null
          ? const Text('No file')
          : Text(_url!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: _busy
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton.icon(
              onPressed: _pickAndUpload,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Upload'),
            ),
    );
  }
}

