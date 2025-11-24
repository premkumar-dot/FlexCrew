// Worker profile edit screen - merged fields with inline country picker and avatar-with-name.
// Includes Preview and Save actions in AppBar. Persists to Firestore collection "workers".
import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flexcrew/widgets/avatar_with_name.dart';
import 'package:flexcrew/widgets/phone_field_with_flag.dart';
import '../../services/storage_service.dart' as storage_service;
import 'package:flexcrew/widgets/user_avatar_button.dart';
import 'package:flexcrew/features/profile/worker_profile_review_screen.dart';
import 'package:flexcrew/widgets/notification_bell.dart';

class WorkerProfileEditScreen extends StatefulWidget {
  const WorkerProfileEditScreen({super.key});

  @override
  State<WorkerProfileEditScreen> createState() => _WorkerProfileEditScreenState();
}

class _WorkerProfileEditScreenState extends State<WorkerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  bool _formReady = false;

  // Controllers
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();

  // Extra fields
  final _dobCtrl = TextEditingController();
  DateTime? _dob;
  String _gender = 'Male';
  String _city = 'Singapore';
  String _preferredArea = 'All Areas';
  String _skills = 'F&B Service';
  final _otherSkillsCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  // Emergency contact
  final _ecNameCtrl = TextEditingController();
  final _ecPhoneCtrl = TextEditingController();
  final _ecWhatsappCtrl = TextEditingController();
  String _ecRelation = 'Parent';

  // Avatar
  String? _avatarUrl;
  double _avatarUploadProgress = 0.0;

  // Country selection (ISO codes)
  String _phoneIso = 'SG';
  String _ecIso = 'SG';

  // Local record id (uid)
  String? _uid;

  static const List<String> _skillsOptions = <String>[
    'F&B Service',
    'Kitchen Helper',
    'Cashier',
    'Barista',
    'Cleaner',
    'Driver',
    'Ad-hoc',
    'Others',
  ];

  static const List<String> _relationOptions = <String>[
    'Parent',
    'Spouse',
    'Sibling',
    'Friend',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _uid = user?.uid;
    _phoneIso = ui.PlatformDispatcher.instance.locale.countryCode ?? 'SG';
    _ecIso = _phoneIso;
    if (user != null) {
      _nameCtrl.text = user.displayName ?? (user.email?.split('@').first ?? '');
      _loadWorkerDoc(user.uid);
    }
    _nameCtrl.addListener(() {
      if (mounted) setState(() {});
    });

    // Mark the form as ready after the first frame so AppBar save can be enabled.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _formReady = true);
    });
  }

  Future<void> _loadWorkerDoc(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
      final data = snap.data();
      if (data != null) {
        setState(() {
          _nameCtrl.text = (data['name'] ?? _nameCtrl.text) as String;
          final phone = data['phone'] as String? ?? '';
          _phoneCtrl.text = _stripDial(phone);
          _whatsappCtrl.text = _stripDial(data['whatsapp'] as String? ?? '');
          _addressCtrl.text = data['address'] as String? ?? '';
          _postalCtrl.text = data['postalCode'] as String? ?? '';
          _avatarUrl = data['photoUrl'] as String?;

          _phoneIso = (data['phoneIso'] as String?) ?? _phoneIso;
          _ecIso = (data['emergencyContactPhoneIso'] as String?) ?? _ecIso;
          final whatsappIso = (data['whatsappIso'] as String?) ?? _phoneIso;
          _phoneIso = whatsappIso.isNotEmpty ? whatsappIso : _phoneIso;

          final dobStr = data['dob'] as String? ?? '';
          if (dobStr.isNotEmpty) {
            try {
              _dob = DateTime.parse(dobStr);
              _dobCtrl.text = "${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}";
            } catch (_) {}
          }
          _gender = data['gender'] as String? ?? _gender;
          _city = data['city'] as String? ?? _city;
          _preferredArea = data['preferredArea'] as String? ?? _preferredArea;
          final skillsVal = data['skills'];
          if (skillsVal is String && skillsVal.isNotEmpty) {
            if (_skillsOptions.contains(skillsVal)) {
              _skills = skillsVal;
            } else {
              _skills = 'Others';
              _otherSkillsCtrl.text = skillsVal;
            }
          }
          _rateCtrl.text = (data['expectedRate']?.toString() ?? _rateCtrl.text);
          _ecNameCtrl.text = data['emergencyContactName'] as String? ?? '';
          final ecPhone = data['emergencyContactPhone'] as String? ?? '';
          _ecPhoneCtrl.text = _stripDial(ecPhone);
          _ecWhatsappCtrl.text = _stripDial(data['emergencyContactWhatsapp'] as String? ?? '');
          _ecRelation = data['emergencyContactRelation'] as String? ?? _ecRelation;
        });
      }
    } catch (_) {}
  }

  // Fix: strip only the known dial prefix and keep the local number.
  String _stripDial(String e164) {
    if (e164.isEmpty) return '';
    final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    const knownDials = ['65', '91', '63', '60', '1'];
    for (final dial in knownDials) {
      if (digits.startsWith(dial)) {
        return digits.substring(dial.length);
      }
    }
    return digits;
  }

  String _dialForIso(String iso) {
    const countryList = [
      {'iso': 'SG', 'dial': '+65'},
      {'iso': 'US', 'dial': '+1'},
      {'iso': 'MY', 'dial': '+60'},
      {'iso': 'PH', 'dial': '+63'},
      {'iso': 'IN', 'dial': '+91'},
    ];
    final c = countryList.firstWhere((c) => c['iso'] == iso, orElse: () => countryList.first);
    return c['dial'] ?? '+65';
  }

  String _normalizeWithDialCode(String raw, String iso) {
    final txt = raw.trim();
    if (txt.isEmpty) return '';
    if (txt.startsWith('+')) {
      final digits = txt.replaceAll(RegExp(r'[^0-9]'), '');
      return '+$digits';
    }
    final digits = txt.replaceAll(RegExp(r'[^0-9]'), '');
    final dial = _dialForIso(iso).replaceAll('+', '');
    return '+$dial$digits';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 25, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 13, now.month, now.day),
    );
    if (picked != null && mounted) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = "${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _uploadAvatar() async {
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

    setState(() => _avatarUploadProgress = 0.0);
    try {
      final url = await storage_service.StorageService.instance.uploadAvatarWithProgress(
        uid: _uid!,
        bytes: bytes,
        contentType: contentType,
        onProgress: (p) {
          if (mounted) setState(() => _avatarUploadProgress = p);
        },
      );
      setState(() => _avatarUrl = url);
      await FirebaseFirestore.instance.collection('workers').doc(_uid).set({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    } catch (_) {}
    if (mounted) setState(() => _avatarUploadProgress = 0.0);
  }

  // Dedicated validation method
  bool _validateForm() {
    final formState = _formKey.currentState;
    if (formState == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Form not ready. Try again.')));
      return false;
    }
    final valid = formState.validate();
    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fix validation errors')));
      return false;
    }
    return true;
  }

  // ----------------- Enhanced _save with better debug logging -----------------
  Future<void> _save() async {
    // debug: print auth and app info up-front
    final currentUser = FirebaseAuth.instance.currentUser;
    // ignore: avoid_print
    print('STEP0: DEBUG currentUser -> uid=${currentUser?.uid} displayName=${currentUser?.displayName} email=${currentUser?.email}');
    try {
      final app = FirebaseFirestore.instance.app;
      // ignore: avoid_print
      print('STEP0: DEBUG Firebase app name=${app.name} projectId=${app.options.projectId}');
    } catch (e) {
      // ignore: avoid_print
      print('STEP0: DEBUG failed to read Firebase app options: $e');
    }

    // Step 1: validation
    // ignore: avoid_print
    print('STEP1: validation start');

    if (!_validateForm()) {
      // validation method already shows SnackBar/logs
      return;
    }

    // ensure _uid present
    if (_uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      // ignore: avoid_print
      print('STEP1: _uid is null, aborting');
      return;
    }
    // Step 2: prepare payload
    setState(() => _saving = true);
    try {
      // ignore: avoid_print
      print('STEP2: preparing payload');
      final phone = _normalizeWithDialCode(_phoneCtrl.text, _phoneIso);
      final whatsapp = _whatsappCtrl.text.trim().isEmpty ? null : _normalizeWithDialCode(_whatsappCtrl.text, _phoneIso);
      final ecPhone = _normalizeWithDialCode(_ecPhoneCtrl.text, _ecIso);
      final ecWhatsapp = _ecWhatsappCtrl.text.trim().isEmpty ? null : _normalizeWithDialCode(_ecWhatsappCtrl.text, _ecIso);
      final skillsVal = _skills == 'Others' ? _otherSkillsCtrl.text.trim() : _skills;
      final normalizedName = _nameCtrl.text.trim();

      final patch = {
        'name': normalizedName,
        'phone': phone,
        'phoneIso': _phoneIso,
        'whatsapp': whatsapp,
        'whatsappIso': _phoneIso,
        'address': _addressCtrl.text.trim(),
        'postalCode': _postalCtrl.text.trim(),
        'photoUrl': _avatarUrl,
        'dob': _dob?.toIso8601String(),
        'gender': _gender,
        'city': _city,
        'preferredArea': _preferredArea,
        'skills': skillsVal,
        'expectedRate': _rateCtrl.text.trim(),
        'emergencyContactName': _ecNameCtrl.text.trim(),
        'emergencyContactPhone': ecPhone,
        'emergencyContactWhatsapp': ecWhatsapp,
        'emergencyContactRelation': _ecRelation,
        'emergencyContactPhoneIso': _ecIso,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // ignore: avoid_print
      print('STEP3: about to write workers/$_uid payload -> $patch');

      final collectionName = 'workers';

      // Step 3: write (wrapped to capture exceptions)
      try {
        // ignore: avoid_print
        print('STEP3.1: write start');
        await FirebaseFirestore.instance
            .collection(collectionName)
            .doc(_uid)
            .set(patch, SetOptions(merge: true))
            .timeout(const Duration(seconds: 12));
        // ignore: avoid_print
        print('STEP3.2: write completed');
      } catch (e, st) {
        // ignore: avoid_print
        print('STEP3.ERROR: write failed -> $e\n$st');
        rethrow;
      }

      // Step 4: read-back
      try {
        // ignore: avoid_print
        print('STEP4: read-back start');
        final after = await FirebaseFirestore.instance.collection('workers').doc(_uid).get();
        final afterData = after.data();
        // ignore: avoid_print
        print('STEP4: workers/$_uid after write -> $afterData');

        if (afterData != null) {
          final newName = (afterData['name'] as String?)?.trim();
          final newPhoto = (afterData['photoUrl'] as String?)?.trim();
          if (newName != null && newName.isNotEmpty) {
            if (mounted) {
              setState(() {
                _nameCtrl.text = newName;
                if (newPhoto != null && newPhoto.isNotEmpty) _avatarUrl = newPhoto;
              });
            }
          }
        }
      } catch (e, st) {
        // ignore: avoid_print
        print('STEP4.ERROR: read-back failed -> $e\n$st');
      }

      // Step 5: update Auth displayName
      try {
        // ignore: avoid_print
        print('STEP5: updating Auth displayName start');
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await user.updateDisplayName(normalizedName);
          await user.reload();
          final refreshed = FirebaseAuth.instance.currentUser;
          // ignore: avoid_print
          print('STEP5: Auth currentUser.displayName after update -> ${refreshed?.displayName}');
        } else {
          // ignore: avoid_print
          print('STEP5: no auth user to update');
        }
      } catch (e, st) {
        // ignore: avoid_print
        print('STEP5.ERROR: Auth update failed -> $e\n$st');
      }

      // Step 6: update users/{uid}
      try {
        // ignore: avoid_print
        print('STEP6: updating users/{uid}');
        await FirebaseFirestore.instance.collection('users').doc(_uid).set({
          'displayName': normalizedName,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        final udoc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
        // ignore: avoid_print
        print('STEP6: users/$_uid after write -> ${udoc.data()}');
      } catch (e, st) {
        // ignore: avoid_print
        print('STEP6.ERROR: users doc update failed -> $e\n$st');
      }

      // success
      // ignore: avoid_print
      print('STEP7: Profile saved successfully for uid=$_uid');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  // -------------------------------------------------------------------------

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _postalCtrl.dispose();
    _dobCtrl.dispose();
    _otherSkillsCtrl.dispose();
    _rateCtrl.dispose();
    _ecNameCtrl.dispose();
    _ecPhoneCtrl.dispose();
    _ecWhatsappCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFF6A00);

    final displayNameForAvatar = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()
        : (FirebaseAuth.instance.currentUser?.displayName ?? '');

    return Scaffold(
      appBar: AppBar(
        // keep toolbarHeight so top-right avatar can show name without overflow
        toolbarHeight: 72,
        title: const Text('Edit profile'),
        backgroundColor: brand,
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: 'Preview',
            icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
            onPressed: () async {
              // prepare preview payload (lightweight)
              final previewData = {
                'photoUrl': _avatarUrl,
                'name': _nameCtrl.text.trim(),
                'phone': _phoneCtrl.text.trim(),
                'whatsapp': _whatsappCtrl.text.trim(),
                'address': _addressCtrl.text.trim(),
                'postalCode': _postalCtrl.text.trim(),
                'dob': _dobCtrl.text.trim(),
                'gender': _gender,
                'city': _city,
                'skills': _skills == 'Others' ? _otherSkillsCtrl.text.trim() : _skills,
                'expectedRate': _rateCtrl.text.trim(),
                'idFrontUrl': null,
                'idBackUrl': null,
                'resumeUrl': null,
              };

              final confirmed = await Navigator.of(context).push<bool?>(
                MaterialPageRoute(builder: (_) => WorkerProfileReviewScreen(data: previewData)),
              );
              if (confirmed == true) {
                await _save();
              }
            },
          ),
          TextButton(
            onPressed: (!_formReady || _saving) ? null : _save,
            child: _saving
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          UserAvatarButton(basePath: '/worker'),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 20 + bottomInset),
            child: ConstrainedBox(
              // Ensure the scroll area is at least the viewport height so content can expand/scroll.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AvatarWithName(
                      imageUrl: _avatarUrl,
                      displayName: displayNameForAvatar,
                      radius: 48,
                      onTap: _uploadAvatar,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    PhoneFieldWithFlag(
                      controller: _phoneCtrl,
                      initialIso: _phoneIso,
                      initialDial: _dialForIso(_phoneIso),
                      onCountrySelected: (c) => setState(() => _phoneIso = c.countryCode),
                      hintText: 'Mobile number',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    PhoneFieldWithFlag(
                      controller: _whatsappCtrl,
                      initialIso: _phoneIso,
                      initialDial: _dialForIso(_phoneIso),
                      onCountrySelected: (c) => setState(() => _phoneIso = c.countryCode),
                      hintText: 'WhatsApp (optional)',
                      validator: (v) => null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _postalCtrl,
                      decoration: const InputDecoration(labelText: 'Postal code', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _dobCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Date of birth', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                      onTap: _pickDob,
                      validator: (v) {
                        if (_dob == null) return 'Select date of birth';
                        final now = DateTime.now();
                        if (_dob!.isAfter(now)) return 'Invalid date';
                        final age = now.year - _dob!.year - ((now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) ? 1 : 0);
                        if (age < 13) return 'Must be at least 13 years old';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (v) => setState(() => _gender = v ?? 'Other'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _rateCtrl,
                      decoration: const InputDecoration(labelText: 'Expected hourly rate', border: OutlineInputBorder(), prefixText: '\$'),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _skills,
                      decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder()),
                      items: _skillsOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                      onChanged: (v) => setState(() => _skills = v ?? _skillsOptions.first),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    if (_skills == 'Others') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _otherSkillsCtrl,
                        decoration: const InputDecoration(labelText: 'Other skills', border: OutlineInputBorder()),
                        validator: (v) => (_skills == 'Others' && (v == null || v.trim().isEmpty)) ? 'Required' : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Align(alignment: Alignment.centerLeft, child: Text('Emergency contact', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _ecNameCtrl,
                      decoration: const InputDecoration(labelText: 'Contact name', border: OutlineInputBorder()),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    PhoneFieldWithFlag(
                      controller: _ecPhoneCtrl,
                      initialIso: _ecIso,
                      initialDial: _dialForIso(_ecIso),
                      onCountrySelected: (c) => setState(() => _ecIso = c.countryCode),
                      hintText: 'Phone No',
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    PhoneFieldWithFlag(
                      controller: _ecWhatsappCtrl,
                      initialIso: _ecIso,
                      initialDial: _dialForIso(_ecIso),
                      onCountrySelected: (c) => setState(() => _ecIso = c.countryCode),
                      hintText: 'WhatsApp (optional)',
                      validator: (v) => null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _ecRelation,
                      decoration: const InputDecoration(labelText: 'Relation', border: OutlineInputBorder()),
                      items: _relationOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (v) => setState(() => _ecRelation = v ?? _relationOptions.first),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: (!_formReady || _saving) ? null : _save,
                            style: ElevatedButton.styleFrom(backgroundColor: brand),
                            child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Save'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
