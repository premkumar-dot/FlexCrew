import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  @override
  void dispose() {
    _companyCtrl.dispose();
    _contactCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_companyCtrl.text.trim().isEmpty || _contactCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill company and contact')));
      return;
    }
    // For onboarding finish, jump to employer home or profile edit
    context.go('/employer/profile/edit');
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFF6A00);
    return Scaffold(
      appBar: AppBar(title: const Text('Employer Onboarding'), backgroundColor: brand),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Welcome — Employer', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextFormField(controller: _companyCtrl, decoration: const InputDecoration(labelText: 'Company name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Primary contact name', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Contact phone', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v ?? false),
            title: const Text('I agree to terms & conditions'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: brand),
            onPressed: _agreed ? _next : null,
            child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Text('Continue')),
          ),
        ]),
      ),
    );
  }
}
