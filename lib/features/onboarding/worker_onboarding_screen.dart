// Worker onboarding – full Stepper UI with country selector, document/avatar upload.
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flexcrew/widgets/phone_field_with_flag.dart';
import 'package:flexcrew/widgets/avatar_with_name.dart';
import 'package:flexcrew/widgets/notification_bell.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';
import '../../services/storage_service.dart' as storage_service;

class WorkerOnboardingScreen extends StatefulWidget {
  const WorkerOnboardingScreen({super.key, this.prefillName, this.prefillUid});

  final String? prefillName;
  final String? prefillUid;

  @override
  State<WorkerOnboardingScreen> createState() => _WorkerOnboardingScreenState();
}

class _WorkerOnboardingScreenState extends State<WorkerOnboardingScreen> {
  final _formKeyPersonal = GlobalKey<FormState>();
  final _formKeyEmergency = GlobalKey<FormState>();
  final _formKeyPrefs = GlobalKey<FormState>();

  int _step = 0;
  bool _submitting = false;
  bool _agreed = true;

  // Personal
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  String _gender = 'Male';

  // Country selectors (ISO codes)
  String _phoneCountryIso = 'SG';
  String _ecCountryIso = 'SG';

  // DOB
  DateTime? _dob;
  final _dobCtl = TextEditingController();

  // Avatar
  String? _avatarUrl;
  double _avatarUploadProgress = 0.0;

  // Preferences
  String _city = 'Singapore';
  String _preferredArea = 'All Areas';
  String _skills = 'F&B Service';
  final _otherSkillsCtrl = TextEditingController();
  final _rateCtrl = TextEditingController(text: '15');

  // Emergency contact
  final _ecNameCtl = TextEditingController();
  final _ecPhoneCtl = TextEditingController();
  final _ecWhatsappCtl = TextEditingController();
  String _ecRelation = 'Parent';

  // Document display names and urls (for Firestore)
  final Map<String, String> _docNames = <String, String>{
    'idFrontUrl': '',
    'idBackUrl': '',
    'resumeUrl': '',
  };
  final Map<String, String> _docUrls = <String, String>{
    'idFrontUrl': '',
    'idBackUrl': '',
    'resumeUrl': '',
  };

  final Map<String, bool> _uploadingDocs = <String, bool>{
    'idFrontUrl': false,
    'idBackUrl': false,
    'resumeUrl': false,
  };

  static const List<Map<String, String>> _countryList = [
    {'iso': 'SG', 'dial': '+65', 'name': 'Singapore'},
    {'iso': 'US', 'dial': '+1', 'name': 'United States'},
    {'iso': 'MY', 'dial': '+60', 'name': 'Malaysia'},
    {'iso': 'PH', 'dial': '+63', 'name': 'Philippines'},
    {'iso': 'IN', 'dial': '+91', 'name': 'India'},
  ];

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
    final localeCountry = ui.PlatformDispatcher.instance.locale.countryCode;
    _phoneCountryIso = (localeCountry != null && localeCountry.isNotEmpty) ? localeCountry : 'SG';
    _ecCountryIso = _phoneCountryIso;

    // Prefill name if passed from create-account flow
    if (widget.prefillName != null && widget.prefillName!.isNotEmpty) {
      _nameCtrl.text = widget.prefillName!;
    }

    // Immediately prefer currentUser if present
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _nameCtrl.text = user.displayName ?? (user.email?.split('@').first ?? '');
    }

    // Listen for auth state changes and update name when auth becomes available
    FirebaseAuth.instance.authStateChanges().listen((u) {
      if (u != null) {
        final name = u.displayName ?? (u.email?.split('@').first ?? '');
        if (name.isNotEmpty && mounted) setState(() => _nameCtrl.text = name);
      } else {
        // If not signed in, try to read users/{prefillUid} as a fallback
        if (widget.prefillUid != null) {
          FirebaseFirestore.instance.collection('users').doc(widget.prefillUid).get().then((doc) {
            final dn = doc.data()?['displayName'] as String?;
            if (dn != null && dn.isNotEmpty && mounted) setState(() => _nameCtrl.text = dn);
          }).catchError((_) {});
        }
      }
    });

    _nameCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _whatsappCtrl.dispose();
    _addressCtrl.dispose();
    _postalCtrl.dispose();
    _idCtrl.dispose();
    _otherSkillsCtrl.dispose();
    _rateCtrl.dispose();
    _ecNameCtl.dispose();
    _ecPhoneCtl.dispose();
    _ecWhatsappCtl.dispose();
    _dobCtl.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    return null;
  }

  String? _dobValidator(String? v) {
    if (_dob == null) return 'Select date of birth';
    final now = DateTime.now();
    if (_dob!.isAfter(now)) return 'Invalid date';
    final age = now.year - _dob!.year - ((now.month < _dob!.month || (now.month == _dob!.month && now.day < _dob!.day)) ? 1 : 0);
    if (age < 13) return 'Must be at least 13 years old';
    return null;
  }

  String _isoToFlag(String iso) {
    if (iso.length != 2) return iso;
    final a = iso.toUpperCase().codeUnitAt(0);
    final b = iso.toUpperCase().codeUnitAt(1);
    const base = 0x1F1E6;
    return String.fromCharCode(base + (a - 65)) + String.fromCharCode(base + (b - 65));
  }

  String _dialForIso(String iso) {
    final country = _countryList.firstWhere((c) => c['iso'] == iso, orElse: () => _countryList.first);
    return country['dial'] ?? '+65';
  }

  String _normalizeWithDialCode(String raw, String iso) {
    final txt = raw.trim();
    if (txt.isEmpty) return '';
    if (txt.startsWith('+')) return txt;
    final digits = txt.replaceAll(RegExp(r'[^0-9]'), '');
    final country = _countryList.firstWhere((c) => c['iso'] == iso, orElse: () => _countryList.first);
    final dial = country['dial']!.replaceAll('+', '');
    return '+$dial$digits';
  }

  Future<String?> _resolvedUid() async {
    var uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null && widget.prefillUid != null) {
      // try reload currentUser first (best-effort)
      try {
        final cur = FirebaseAuth.instance.currentUser;
        if (cur != null) await cur.reload();
      } catch (_) {}
      uid = FirebaseAuth.instance.currentUser?.uid ?? widget.prefillUid;
    }
    return uid;
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
        // Display date in dd-MMM-yyyy (02-Jan-2020)
        _dobCtl.text = DateFormat('dd-MMM-yyyy').format(picked);
      });
    }
  }

  Future<void> _pickDocumentAndUpload(String key) async {
    final uid = await _resolvedUid();
    if (uid == null) {
      _toast('Not signed in.');
      return;
    }

    final result = await FilePicker.platform.pickFiles(type: FileType.any, allowMultiple: false, withData: true);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    final name = f.name;
    final bytes = f.bytes;
    if (bytes == null) {
      _toast('Failed to read file.');
      return;
    }

    setState(() {
      _docNames[key] = name;
      _uploadingDocs[key] = true;
      _docUrls[key] = '';
    });

    final ext = (f.extension ?? '').toLowerCase();
    String contentType = 'application/octet-stream';
    if (['jpg', 'jpeg'].contains(ext)) contentType = 'image/jpeg';
    if (ext == 'png') contentType = 'image/png';
    if (ext == 'pdf') contentType = 'application/pdf';

    try {
      final path = storage_service.StorageService.instance.pathForWorkerDoc(uid, name);
      final url = await storage_service.StorageService.instance.uploadBytes(path: path, data: bytes, contentType: contentType);
      setState(() {
        _docUrls[key] = url;
        _docNames[key] = name;
      });
      _toast('Uploaded $name');
    } catch (e) {
      _toast('Upload failed: $e');
      setState(() {
        _docNames[key] = '';
        _docUrls[key] = '';
      });
    } finally {
      setState(() {
        _uploadingDocs[key] = false;
      });
    }
  }

  Future<void> _uploadAvatar() async {
    final uid = await _resolvedUid();
    if (uid == null) {
      _toast('Not signed in.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _toast('Failed to read image.');
      return;
    }

    final ext = (file.extension ?? 'jpg').toLowerCase();
    String contentType = 'image/jpeg';
    if (ext == 'png') contentType = 'image/png';
    if (ext == 'webp') contentType = 'image/webp';

    setState(() => _avatarUploadProgress = 0.0);

    try {
      final url = await storage_service.StorageService.instance.uploadAvatarWithProgress(
        uid: uid,
        bytes: bytes,
        contentType: contentType,
        onProgress: (p) {
          if (mounted) setState(() => _avatarUploadProgress = p);
        },
      );
      if (mounted) setState(() => _avatarUrl = url);
      // Persist avatar to users/{uid} and also update FirebaseAuth.currentUser.photoURL
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } catch (_) {}
      try {
        final authUser = FirebaseAuth.instance.currentUser;
        if (authUser != null) {
          await authUser.updatePhotoURL(url);
          await authUser.reload();
        }
      } catch (_) {}
      _toast('Avatar uploaded.');
    } catch (e) {
      _toast('Avatar upload failed: $e');
    } finally {
      if (mounted) setState(() => _avatarUploadProgress = 0.0);
    }
  }

  Future<void> _submit() async {
    if (!_agreed) {
      _toast('Please agree to the Terms & Conditions.');
      return;
    }
    if (!_formKeyPersonal.currentState!.validate()) {
      setState(() => _step = 0);
      return;
    }
    if (!_formKeyEmergency.currentState!.validate()) {
      setState(() => _step = 1);
      return;
    }
    if (!_formKeyPrefs.currentState!.validate()) {
      setState(() => _step = 2);
      return;
    }

    final uid = await _resolvedUid();
    if (uid == null) {
      _toast('Not signed in.');
      return;
    }

    setState(() => _submitting = true);

    try {
      final phoneE164 = _normalizeWithDialCode(_phoneCtrl.text, _phoneCountryIso);
      final whatsappE164 = _whatsappCtrl.text.trim().isEmpty ? null : _normalizeWithDialCode(_whatsappCtrl.text, _phoneCountryIso);
      final ecPhoneE164 = _normalizeWithDialCode(_ecPhoneCtl.text, _ecCountryIso);
      final ecWhatsappE164 = _ecWhatsappCtl.text.trim().isEmpty ? null : _normalizeWithDialCode(_ecWhatsappCtl.text, _ecCountryIso);

      final finalSkills = _skills == 'Others' ? _otherSkillsCtrl.text.trim() : _skills;

      final data = {
        'uid': uid,
        'email': FirebaseAuth.instance.currentUser?.email,
        'name': _nameCtrl.text.trim(),
        'phone': phoneE164,
        'whatsapp': whatsappE164,
        'address': _addressCtrl.text.trim(),
        'postalCode': _postalCtrl.text.trim(),
        'idNumber': _idCtrl.text.trim(),
        'gender': _gender,
        'dob': _dob?.toIso8601String(),
        'city': _city,
        'preferredArea': _preferredArea,
        'skills': finalSkills,
        'expectedRate': _rateCtrl.text.trim(),
        'onboarded': true,
        'photoUrl': _avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
        'emergencyContactName': _ecNameCtl.text.trim(),
        'emergencyContactPhone': ecPhoneE164,
        'emergencyContactWhatsapp': ecWhatsappE164,
        'emergencyContactRelation': _ecRelation,
        'idFrontUrl': _docUrls['idFrontUrl'],
        'idBackUrl': _docUrls['idBackUrl'],
        'resumeUrl': _docUrls['resumeUrl'],
      };

      await FirebaseFirestore.instance.collection('workers').doc(uid).set(data, SetOptions(merge: true));

      // Explicitly set role -> worker in users/{uid} so role is set only from onboarding flows
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'role': 'worker',
          'onboardingComplete': true,
          'displayName': _nameCtrl.text.trim(),
          'phone': phoneE164,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}
      _toast('Onboarding saved.');
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        try {
          context.go('/login');
        } catch (_) {
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
        }
      }
    } catch (e) {
      _toast('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Crew Onboarding'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: const [NotificationBell()],
      ),
      body: Stepper(
        type: StepperType.vertical,
        currentStep: _step,
        onStepContinue: () {
          if (_step == 0) {
            if (_formKeyPersonal.currentState!.validate()) setState(() => _step = 1);
          } else if (_step == 1) {
            if (_formKeyEmergency.currentState!.validate()) setState(() => _step = 2);
          } else if (_step == 2) {
            if (_formKeyPrefs.currentState!.validate()) setState(() => _step = 3);
          }
        },
        onStepCancel: () {
          if (_step > 0) setState(() => _step -= 1);
        },
        controlsBuilder: (ctx, details) {
          final isLast = _step == 3;
          return Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                if (!isLast) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: onPrimary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: details.onStepContinue,
                    child: const Text('Next'),
                  ),
                  const SizedBox(width: 12),
                  if (_step > 0) TextButton(onPressed: details.onStepCancel, child: const Text('Back')),
                ] else ...[
                  if (_step > 0) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: const StadiumBorder()),
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: onPrimary, shape: const StadiumBorder(), padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Personal'),
            isActive: _step >= 0,
            state: _step > 0 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKeyPersonal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  AvatarWithName(
                    imageUrl: _avatarUrl,
                    displayName: _nameCtrl.text,
                    radius: 48,
                    onTap: _uploadAvatar,
                  ),
                  const SizedBox(height: 16),
                  _LabeledField(label: 'Full name', icon: Icons.person, controller: _nameCtrl, validator: _requiredValidator),
                  const SizedBox(height: 12),
                  PhoneFieldWithFlag(
                    controller: _phoneCtrl,
                    initialIso: _phoneCountryIso,
                    initialDial: _dialForIso(_phoneCountryIso),
                    onCountrySelected: (country) {
                      setState(() => _phoneCountryIso = country.countryCode);
                    },
                    hintText: 'Mobile number',
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  PhoneFieldWithFlag(
                    controller: _whatsappCtrl,
                    initialIso: _phoneCountryIso,
                    initialDial: _dialForIso(_phoneCountryIso),
                    onCountrySelected: (country) {
                      setState(() => _phoneCountryIso = country.countryCode);
                    },
                    hintText: 'WhatsApp (optional)',
                    validator: (v) => null,
                  ),
                  const SizedBox(height: 12),
                  _LabeledField(label: 'Address', icon: Icons.home, controller: _addressCtrl, validator: _requiredValidator),
                  const SizedBox(height: 12),
                  _LabeledField(label: 'Postal Code', icon: Icons.mail, controller: _postalCtrl, validator: _requiredValidator),
                  const SizedBox(height: 12),
                  _LabeledField(label: 'NRIC/FIN/Passport Number', icon: Icons.badge, controller: _idCtrl, validator: _requiredValidator),
                  const SizedBox(height: 12),
                  TextFormField(controller: _dobCtl, readOnly: true, decoration: const InputDecoration(labelText: 'Date of birth', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)), onTap: _pickDob, validator: _dobValidator),
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
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Emergency Contact'),
            isActive: _step >= 1,
            state: _step > 1 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKeyEmergency,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LabeledField(label: 'Contact name', icon: Icons.person, controller: _ecNameCtl, validator: _requiredValidator),
                  const SizedBox(height: 12),
                  PhoneFieldWithFlag(
                    controller: _ecPhoneCtl,
                    initialIso: _ecCountryIso,
                    initialDial: _dialForIso(_ecCountryIso),
                    onCountrySelected: (country) => setState(() => _ecCountryIso = country.countryCode),
                    hintText: 'Phone No',
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 12),
                  PhoneFieldWithFlag(
                    controller: _ecWhatsappCtl,
                    initialIso: _ecCountryIso,
                    initialDial: _dialForIso(_ecCountryIso),
                    onCountrySelected: (country) => setState(() => _ecCountryIso = country.countryCode),
                    hintText: 'Emergency WhatsApp (optional)',
                    validator: (v) => null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _ecRelation,
                    decoration: const InputDecoration(labelText: 'Relation', border: OutlineInputBorder()),
                    items: _relationOptions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (v) => setState(() => _ecRelation = v ?? _relationOptions.first),
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Preferences'),
            isActive: _step >= 2,
            state: _step > 2 ? StepState.complete : StepState.indexed,
            content: Form(
              key: _formKeyPrefs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _skills,
                    decoration: const InputDecoration(labelText: 'Skills', border: OutlineInputBorder()),
                    items: _skillsOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => _skills = v ?? _skillsOptions.first),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  if (_skills == 'Others') _LabeledField(label: 'Other skills', icon: Icons.edit, controller: _otherSkillsCtrl, validator: _requiredValidator),
                  const SizedBox(height: 12),
                  _LabeledField(label: 'Expected hourly rate', icon: Icons.attach_money, controller: _rateCtrl, keyboardType: TextInputType.number, validator: _requiredValidator),
                  const SizedBox(height: 12),
                  const Text('Documents (optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  UploadTile(label: 'ID front', filename: _docNames['idFrontUrl']!, uploading: _uploadingDocs['idFrontUrl'] ?? false, onPick: () => _pickDocumentAndUpload('idFrontUrl')),
                  UploadTile(label: 'ID back', filename: _docNames['idBackUrl']!, uploading: _uploadingDocs['idBackUrl'] ?? false, onPick: () => _pickDocumentAndUpload('idBackUrl')),
                  UploadTile(label: 'Resume', filename: _docNames['resumeUrl']!, uploading: _uploadingDocs['resumeUrl'] ?? false, onPick: () => _pickDocumentAndUpload('resumeUrl')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v ?? false)),
                      const Expanded(child: Text('I agree to the Terms & Conditions')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Step(
            title: const Text('Review'),
            isActive: _step >= 3,
            state: _step == 3 ? StepState.complete : StepState.indexed,
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Review your details before submission', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ListTile(leading: const Icon(Icons.person), title: const Text('Full name'), subtitle: Text(_nameCtrl.text.trim().isEmpty ? '?' : _nameCtrl.text.trim())),
                  ListTile(leading: const Icon(Icons.phone), title: const Text('Phone'), subtitle: Text(_phoneCtrl.text.trim().isEmpty ? '?' : _normalizeWithDialCode(_phoneCtrl.text, _phoneCountryIso))),
                  ListTile(leading: const Icon(Icons.chat), title: const Text('WhatsApp'), subtitle: Text(_whatsappCtrl.text.trim().isEmpty ? '?' : _normalizeWithDialCode(_whatsappCtrl.text, _phoneCountryIso))),
                  ListTile(leading: const Icon(Icons.home), title: const Text('Address'), subtitle: Text(_addressCtrl.text.trim().isEmpty ? '?' : _addressCtrl.text.trim())),
                  ListTile(leading: const Icon(Icons.badge), title: const Text('ID Number'), subtitle: Text(_idCtrl.text.trim().isEmpty ? '?' : _idCtrl.text.trim())),
                  ListTile(leading: const Icon(Icons.calendar_today), title: const Text('DOB'), subtitle: Text(_dobCtl.text.isEmpty ? '?' : _dobCtl.text)),
                  ListTile(leading: const Icon(Icons.work), title: const Text('Skills'), subtitle: Text(_skills)),
                  const SizedBox(height: 8),
                  const Text('Uploaded files:', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  if (_docNames['idFrontUrl']!.isNotEmpty) ListTile(leading: const Icon(Icons.insert_drive_file), title: Text('ID front'), subtitle: Text(_docNames['idFrontUrl']!)),
                  if (_docNames['idBackUrl']!.isNotEmpty) ListTile(leading: const Icon(Icons.insert_drive_file), title: Text('ID back'), subtitle: Text(_docNames['idBackUrl']!)),
                  if (_docNames['resumeUrl']!.isNotEmpty) ListTile(leading: const Icon(Icons.insert_drive_file), title: Text('Resume'), subtitle: Text(_docNames['resumeUrl']!)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.check),
                    label: _submitting ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Confirm & Submit'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: onPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small reusable labeled text field used in this file.
class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    this.icon,
    required this.controller,
    this.validator,
    this.enabled = true,
    this.keyboardType,
    super.key,
  });

  final String label;
  final IconData? icon;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool enabled;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      validator: validator,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

/// Simple list-tile uploader row.
class UploadTile extends StatelessWidget {
  const UploadTile({required this.label, required this.filename, required this.onPick, this.uploading = false, super.key});

  final String label;
  final String filename;
  final VoidCallback onPick;
  final bool uploading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.upload_file),
      title: Text(label),
      subtitle: Text(filename.isEmpty ? (uploading ? 'Uploading...' : 'No file selected') : filename, overflow: TextOverflow.ellipsis),
      trailing: uploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : TextButton(onPressed: onPick, child: const Text('Select')),
    );
  }
}
