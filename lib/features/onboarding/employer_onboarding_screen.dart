import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flexcrew/widgets/phone_field_with_flag.dart';

class EmployerOnboardingScreen extends StatefulWidget {
  const EmployerOnboardingScreen({super.key});

  @override
  State<EmployerOnboardingScreen> createState() => _EmployerOnboardingScreenState();
}

class _EmployerOnboardingScreenState extends State<EmployerOnboardingScreen> {
  final _companyCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _agreed = false;
  String _phoneCountryIso = 'SG';

  @override
  void dispose() {
    _companyCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  String _normalizePhone(String raw, String iso) {
    final txt = raw.trim();
    if (txt.isEmpty) return '';
    if (txt.startsWith('+')) return txt;
    final digits = txt.replaceAll(RegExp(r'[^0-9]'), '');
    final dial = iso == 'SG' ? '65' : (iso == 'US' ? '1' : '65');
    return '+$dial$digits';
  }

  void _next() {
    if (_companyCtrl.text.trim().isEmpty || _contactCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill company and contact')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    final phoneNormalized = _normalizePhone(_phoneCtrl.text.trim(), _phoneCountryIso);

    final data = {
      'companyName': _companyCtrl.text.trim(),
      'contactName': _contactCtrl.text.trim(),
      'phone': phoneNormalized,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    FirebaseFirestore.instance.collection('employers').doc(uid).set(data, SetOptions(merge: true)).catchError((_) {});

    FirebaseFirestore.instance.collection('users').doc(uid).set({
      'role': 'employer',
      'onboardingComplete': true,
      'displayName': _contactCtrl.text.trim(),
      'phone': phoneNormalized,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).catchError((_) {});

    try {
      context.go('/employer/profile/edit');
    } catch (_) {
      Navigator.of(context).pushReplacementNamed('/employer/profile/edit');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(title: const Text('Employer Onboarding'), backgroundColor: primary),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Welcome — Employer', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextFormField(
            controller: _companyCtrl,
            decoration: InputDecoration(
              labelText: 'Company name',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _contactCtrl,
            decoration: InputDecoration(
              labelText: 'Primary contact name',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          const SizedBox(height: 12),
          PhoneFieldWithFlag(
            controller: _phoneCtrl,
            initialIso: _phoneCountryIso,
            initialDial: _dialForIso(_phoneCountryIso),
            onCountrySelected: (country) => setState(() => _phoneCountryIso = country.countryCode),
            hintText: 'Contact phone',
            validator: (v) => null,
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            title: const Text('I agree to terms & conditions'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primary),
            onPressed: _agreed ? _next : null,
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Continue')),
          ),
        ]),
      ),
    );
  }

  String _dialForIso(String iso) {
    switch (iso) {
      case 'US':
        return '+1';
      case 'MY':
        return '+60';
      case 'PH':
        return '+63';
      case 'IN':
        return '+91';
      default:
        return '+65';
    }
  }
}
