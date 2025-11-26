import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'vacancy_preview_screen.dart';

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
  final _slotsCtrl = TextEditingController(text: '1');
  final _tagsCtrl = TextEditingController();
  DateTime? _startAt;
  DateTime? _endAt;
  DateTime? _applicationDeadline;
  bool _saving = false;

  static final _dateDisplayFmt = DateFormat.yMMMd().add_jm();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _rateCtrl.dispose();
    _slotsCtrl.dispose();
    _tagsCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(BuildContext ctx, DateTime? initial) async {
    final d = await showDatePicker(
      context: ctx,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null) return null;
    final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()));
    if (t == null) return DateTime(d.year, d.month, d.day);
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _previewAndSave() async {
    if (!_formKey.currentState!.validate()) return;

    final tags = _tagsCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final preview = {
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'ratePerHour': _rateCtrl.text.trim().isEmpty ? null : double.tryParse(_rateCtrl.text.trim()),
      'slots': int.tryParse(_slotsCtrl.text.trim()) ?? 1,
      'tags': tags,
      'startAt': _startAt != null ? Timestamp.fromDate(_startAt!) : null,
      'endAt': _endAt != null ? Timestamp.fromDate(_endAt!) : null,
      'applicationDeadline': _applicationDeadline != null ? Timestamp.fromDate(_applicationDeadline!) : null,
    };

    final confirmed = await Navigator.of(context).push<bool?>(MaterialPageRoute(builder: (_) => VacancyPreviewScreen(vacancy: preview)));
    if (confirmed == true) await _save(preview);
  }

  Future<void> _save(Map<String, dynamic> preview) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not Signed In')));
      return;
    }
    setState(() => _saving = true);

    try {
      final data = {
        'title': preview['title'],
        'description': preview['description'],
        'ratePerHour': preview['ratePerHour'],
        'slots': preview['slots'],
        'tags': preview['tags'],
        'startAt': preview['startAt'],
        'endAt': preview['endAt'],
        'applicationDeadline': preview['applicationDeadline'],
        'employerId': uid,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('vacancies').add(data);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vacancy Created')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Create Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateField(String label, DateTime? dt, VoidCallback onTap) {
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), suffixIcon: const Icon(Icons.calendar_today)),
      controller: TextEditingController(text: dt == null ? '' : _dateDisplayFmt.format(dt)),
      onTap: onTap,
      validator: (_) => null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Vacancy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 4,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _rateCtrl,
                    decoration: const InputDecoration(labelText: 'Rate per hour', prefixText: '\$ ', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _slotsCtrl,
                    decoration: const InputDecoration(labelText: 'Slots', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return 'Required';
                      final n = int.tryParse(t);
                      if (n == null || n <= 0) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tagsCtrl,
                decoration: const InputDecoration(labelText: 'Tags (comma separated)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              _dateField('Start date/time', _startAt, () async {
                final picked = await _pickDateTime(context, _startAt);
                if (picked != null && mounted) setState(() => _startAt = picked);
              }),
              const SizedBox(height: 12),
              _dateField('End date/time', _endAt, () async {
                final picked = await _pickDateTime(context, _endAt);
                if (picked != null && mounted) setState(() => _endAt = picked);
              }),
              const SizedBox(height: 12),
              _dateField('Application deadline', _applicationDeadline, () async {
                final picked = await _pickDateTime(context, _applicationDeadline);
                if (picked != null && mounted) setState(() => _applicationDeadline = picked);
              }),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _previewAndSave,
                child: _saving ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Preview & Create'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
