import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flexcrew/widgets/user_avatar_button.dart';
import '../../services/storage_service.dart' as storage_service;
import 'package:flexcrew/features/profile/employer_profile_review_screen.dart';
import 'package:flexcrew/widgets/notification_bell.dart';

class EmployerProfileEditScreen extends StatefulWidget {
  const EmployerProfileEditScreen({super.key});

  @override
  State<EmployerProfileEditScreen> createState() => _EmployerProfileEditScreenState();
}

class _EmployerProfileEditScreenState extends State<EmployerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  final _companyCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String? _logoUrl;
  double _logoUploadProgress = 0.0;
  String? _uid;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    if (user != null) {
      _loadEmployerDoc(user.uid);
    }
  }

  Future<void> _loadEmployerDoc(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('employers').doc(uid).get();
      final data = snap.data();
      if (data != null) {
        setState(() {
          _companyCtrl.text = (data['companyName'] ?? '') as String;
          _contactCtrl.text = (data['contactName'] ?? '') as String;
          _phoneCtrl.text = (data['phone'] ?? '') as String;
          _addressCtrl.text = (data['address'] ?? '') as String;
          _postalCtrl.text = (data['postalCode'] ?? '') as String;
          _websiteCtrl.text = (data['website'] ?? '') as String;
          _descCtrl.text = (data['description'] ?? '') as String;
          _logoUrl = (data['logoUrl'] as String?)?.trim();
        });
      }
    } catch (_) {}
  }

  Future<void> _uploadLogo() async {
    if (_uid == null) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;
    final ext = (file.extension ?? 'jpg').toLowerCase();
    var contentType = 'image/jpeg';
    if (ext == 'png') contentType = 'image/png';
    if (ext == 'webp') contentType = 'image/webp';
    setState(() => _logoUploadProgress = 0.0);
    try {
      final url = await storage_service.StorageService.instance.uploadAvatarWithProgress(
        uid: _uid!,
        bytes: bytes,
        contentType: contentType,
        onProgress: (p) {
          if (mounted) setState(() => _logoUploadProgress = p);
        },
      );
      setState(() => _logoUrl = url);
      await FirebaseFirestore.instance.collection('employers').doc(_uid).set({'logoUrl': url, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _logoUploadProgress = 0.0);
    }
  }

  bool _validateForm() {
    final s = _formKey.currentState;
    if (s == null) return false;
    return s.validate();
  }

  Future<void> _save() async {
    if (!_validateForm()) return;
    if (_uid == null) return;
    setState(() => _saving = true);
    final patch = {
      'companyName': _companyCtrl.text.trim(),
      'contactName': _contactCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'postalCode': _postalCtrl.text.trim(),
      'website': _websiteCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'logoUrl': _logoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await FirebaseFirestore.instance.collection('employers').doc(_uid).set(patch, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _companyCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _postalCtrl.dispose();
    _websiteCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFF6A00);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text('Edit employer profile'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Preview',
            icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
            onPressed: () async {
              final preview = {
                'logoUrl': _logoUrl,
                'companyName': _companyCtrl.text.trim(),
                'contactName': _contactCtrl.text.trim(),
                'phone': _phoneCtrl.text.trim(),
                'address': _addressCtrl.text.trim(),
                'postalCode': _postalCtrl.text.trim(),
                'website': _websiteCtrl.text.trim(),
                'description': _descCtrl.text.trim(),
              };
              final confirmed = await Navigator.of(context).push<bool?>(
                MaterialPageRoute(builder: (_) => EmployerProfileReviewScreen(data: preview)),
              );
              if (confirmed == true) await _save();
            },
          ),
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          const UserAvatarButton(),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(
                child: GestureDetector(
                  onTap: _uploadLogo,
                  child: _logoUrl != null && _logoUrl!.isNotEmpty
                      ? SizedBox(
                          width: 96,
                          height: 96,
                          child: ClipOval(
                            child: Container(
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: Image.network(
                                _logoUrl!,
                                fit: BoxFit.contain,
                                width: 96,
                                height: 96,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 36),
                              ),
                            ),
                          ),
                        )
                      : const ClipOval(
                          child: SizedBox(width: 96, height: 96, child: Icon(Icons.business, size: 40)),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'Company name', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Primary contact', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone', border: OutlineInputBorder()), validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: _postalCtrl, decoration: const InputDecoration(labelText: 'Postal code', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: _websiteCtrl, decoration: const InputDecoration(labelText: 'Website', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Short description', border: OutlineInputBorder()), maxLines: 3),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(onPressed: _saving ? null : _save, style: ElevatedButton.styleFrom(backgroundColor: brand), child: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
