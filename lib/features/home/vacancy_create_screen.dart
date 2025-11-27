import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VacancyCreateScreen extends StatefulWidget {
  const VacancyCreateScreen({super.key});

  @override
  State<VacancyCreateScreen> createState() => _VacancyCreateScreenState();
}

class _VacancyCreateScreenState extends State<VacancyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _dressCtrl = TextEditingController();
  final _slotsCtrl = TextEditingController();

  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _rateCtrl.dispose();
    _locationCtrl.dispose();
    _dressCtrl.dispose();
    _slotsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);

    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text.trim());
    final location = _locationCtrl.text.trim();
    final dress = _dressCtrl.text.trim();
    final slots = int.tryParse(_slotsCtrl.text.trim()) ?? 0;

    // Standardized payload: only 'location' and 'dressCode'
    final payload = {
      'title': title,
      'description': description,
      'ratePerHour': rate,
      'location': location.isNotEmpty ? location : null,
      'dressCode': dress.isNotEmpty ? dress : null,
      'slots': slots,
      'employerId': uid,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }..removeWhere((k, v) => v == null);

    try {
      await _db.collection('vacancies').add(payload);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create vacancy')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('lib/features/home/vacancy_create_screen.dart', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            const Text('Create Vacancy'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rateCtrl,
                decoration: const InputDecoration(labelText: 'Rate (per hour)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'Location (text)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dressCtrl,
                decoration: const InputDecoration(labelText: 'Dress code'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _slotsCtrl,
                decoration: const InputDecoration(labelText: 'Slots'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('Create'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
