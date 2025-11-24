import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateVacancyScreen extends StatefulWidget {
  const CreateVacancyScreen({super.key});
  @override
  State<CreateVacancyScreen> createState() => _CreateVacancyScreenState();
}

class _CreateVacancyScreenState extends State<CreateVacancyScreen> {
  final _formKey = GlobalKey<FormState>();

  // Fields
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController(text: '15');
  final _slots = TextEditingController(text: '1');

  String _type = 'hourly';
  String _category = 'General';
  String _currency = 'SGD';

  DateTime? _startAt;
  DateTime? _endAt;

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    _slots.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime({
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime.now().subtract(const Duration(days: 1)),
      lastDate: lastDate ?? DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? _validate() {
    if (_title.text.trim().isEmpty) return 'Please enter a job title';
    final amt = double.tryParse(_amount.text.replaceAll(',', '').trim());
    if (amt == null || amt <= 0) return 'Please enter a valid wage amount';
    final s = int.tryParse(_slots.text.trim());
    if (s == null || s <= 0) return 'Slots must be a positive number';
    if (_startAt == null) return 'Please pick a start date/time';
    if (_endAt == null) return 'Please pick an end date/time';
    if (!_endAt!.isAfter(_startAt!)) return 'End time must be after start time';
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final amount = double.parse(_amount.text.replaceAll(',', '').trim());
      final slots = int.parse(_slots.text.trim());

      await FirebaseFirestore.instance.collection('vacancies').add({
        'employerId': uid,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'category': _category,
        'wage': {'type': _type, 'amount': amount, 'currency': _currency},
        'shift': {
          'startAt': Timestamp.fromDate(_startAt!),
          'endAt': Timestamp.fromDate(_endAt!),
          'recurring': false,
        },
        'slots': slots,
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vacancy posted ✅')));
      context.go('/employer'); // reliable on web
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to post: $e')));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final spacing = const SizedBox(height: 12);
    final buttonSpacing = const SizedBox(height: 16);

    final startLabel = _startAt == null
        ? 'Pick start date & time'
        : 'Start: ${_startAt!.toLocal()}';
    final endLabel =
        _endAt == null ? 'Pick end date & time' : 'End: ${_endAt!.toLocal()}';

    return Scaffold(
      appBar: AppBar(title: const Text('Post Vacancy')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Job title',
                        hintText: 'e.g., Retail Assistant',
                      ),
                    ),
                    spacing,
                    DropdownButtonFormField(
                      value: _category,
                      items: const [
                        DropdownMenuItem(
                            value: 'General', child: Text('General')),
                        DropdownMenuItem(
                            value: 'Retail', child: Text('Retail')),
                        DropdownMenuItem(value: 'F&B', child: Text('F&B')),
                        DropdownMenuItem(
                            value: 'Events', child: Text('Events')),
                        DropdownMenuItem(
                            value: 'Logistics', child: Text('Logistics')),
                      ],
                      onChanged: (v) => setState(() => _category = v as String),
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    spacing,
                    TextField(
                      controller: _description,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText:
                            'Brief details about duties, attire, location, etc.',
                        alignLabelWithHint: true,
                      ),
                    ),
                    spacing,
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField(
                            value: _type,
                            items: const [
                              DropdownMenuItem(
                                  value: 'hourly', child: Text('Hourly')),
                              DropdownMenuItem(
                                  value: 'daily', child: Text('Daily')),
                            ],
                            onChanged: (v) =>
                                setState(() => _type = v as String),
                            decoration:
                                const InputDecoration(labelText: 'Wage type'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _amount,
                            decoration:
                                const InputDecoration(labelText: 'Wage amount'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField(
                            value: _currency,
                            items: const [
                              DropdownMenuItem(
                                  value: 'SGD', child: Text('SGD')),
                              DropdownMenuItem(
                                  value: 'MYR', child: Text('MYR')),
                              DropdownMenuItem(
                                  value: 'USD', child: Text('USD')),
                            ],
                            onChanged: (v) =>
                                setState(() => _currency = v as String),
                            decoration:
                                const InputDecoration(labelText: 'Currency'),
                          ),
                        ),
                      ],
                    ),
                    spacing,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final initial = _startAt ??
                                  DateTime.now().add(const Duration(hours: 1));
                              final picked =
                                  await _pickDateTime(initialDate: initial);
                              if (picked != null)
                                setState(() => _startAt = picked);
                            },
                            icon: const Icon(Icons.schedule),
                            label: Text(startLabel),
                          ),
                        ),
                      ],
                    ),
                    spacing,
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final initial = _endAt ??
                                  (_startAt != null
                                      ? _startAt!.add(const Duration(hours: 4))
                                      : DateTime.now()
                                          .add(const Duration(hours: 5)));
                              final picked =
                                  await _pickDateTime(initialDate: initial);
                              if (picked != null)
                                setState(() => _endAt = picked);
                            },
                            icon: const Icon(Icons.event),
                            label: Text(endLabel),
                          ),
                        ),
                      ],
                    ),
                    spacing,
                    TextField(
                      controller: _slots,
                      decoration: const InputDecoration(
                          labelText: 'Slots (number of workers)'),
                      keyboardType: TextInputType.number,
                    ),
                    buttonSpacing,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.check),
                        label: Text(_saving ? 'Posting...' : 'Publish'),
                      ),
                    ),
                  ]),
            ),
          ),
        ),
      ),
    );
  }
}

