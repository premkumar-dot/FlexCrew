import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VacancyEditScreen extends StatefulWidget {
  final String vacancyId;
  final Map<String, dynamic> vacancyData;

  // Keep vacancyData optional for callers that don't provide it.
  const VacancyEditScreen({super.key, required this.vacancyId, Map<String, dynamic>? vacancyData})
      : vacancyData = vacancyData ?? const <String, dynamic>{};

  @override
  State<VacancyEditScreen> createState() => _VacancyEditScreenState();
}

class _VacancyEditScreenState extends State<VacancyEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _rateCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _dressCtrl;
  late TextEditingController _slotsCtrl;

  final _db = FirebaseFirestore.instance;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.vacancyData;
    _titleCtrl = TextEditingController(text: d['title'] as String? ?? '');
    _descCtrl = TextEditingController(text: d['description'] as String? ?? '');
    _rateCtrl = TextEditingController(text: (d['ratePerHour'] ?? '').toString());
    _locationCtrl = TextEditingController(text: (d['location'] ?? '').toString());
    _dressCtrl = TextEditingController(text: (d['dressCode'] ?? '').toString());
    _slotsCtrl = TextEditingController(text: (d['slots'] ?? '').toString());
  }

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
    setState(() => _saving = true);

    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text.trim());
    final location = _locationCtrl.text.trim();
    final dress = _dressCtrl.text.trim();
    final slots = int.tryParse(_slotsCtrl.text.trim()) ?? 0;

    final update = <String, dynamic>{
      'title': title,
      'description': description,
      'ratePerHour': rate,
      'location': location.isNotEmpty ? location : FieldValue.delete(),
      'dressCode': dress.isNotEmpty ? dress : FieldValue.delete(),
      'slots': slots,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await _db.collection('vacancies').doc(widget.vacancyId).update(update);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update vacancy')));
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
            Text('mobile/lib/features/home/vacancy_edit_screen.dart', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 2),
            const Text('Edit Vacancy'),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Form(
            key: _formKey,
            child: Column(children: [
              TextFormField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Title'), validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), maxLines: 4),
              const SizedBox(height: 8),
              TextFormField(controller: _rateCtrl, decoration: const InputDecoration(labelText: 'Rate (per hour)'), keyboardType: TextInputType.number),
              const SizedBox(height: 8),
              TextFormField(controller: _locationCtrl, decoration: const InputDecoration(labelText: 'Location (text)')),
              const SizedBox(height: 8),
              TextFormField(controller: _dressCtrl, decoration: const InputDecoration(labelText: 'Dress code')),
              const SizedBox(height: 8),
              TextFormField(controller: _slotsCtrl, decoration: const InputDecoration(labelText: 'Slots'), keyboardType: TextInputType.number),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _saving ? null : _save, child: _saving ? const CircularProgressIndicator() : const Text('Save')),
            ]),
          ),
        ),
      ),
    );
  }
}
