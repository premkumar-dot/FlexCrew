import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EditVacancyScreen extends StatefulWidget {
  final String id;
  const EditVacancyScreen({super.key, required this.id});
  @override
  State<EditVacancyScreen> createState() => _EditVacancyScreenState();
}

class _EditVacancyScreenState extends State<EditVacancyScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _amount = TextEditingController();
  final _slots = TextEditingController();
  String _type = 'hourly';
  String _category = 'General';
  String _currency = 'SGD';
  DateTime? _startAt;
  DateTime? _endAt;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _amount.dispose();
    _slots.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('vacancies')
        .doc(widget.id)
        .get();
    final m = doc.data() as Map<String, dynamic>?;

    if (m != null) {
      _title.text = m['title'] ?? '';
      _description.text = m['description'] ?? '';
      _category = m['category'] ?? 'General';
      final wage = (m['wage'] ?? {}) as Map<String, dynamic>;
      _type = wage['type'] ?? 'hourly';
      _amount.text = (wage['amount'] ?? '').toString();
      _currency = wage['currency'] ?? 'SGD';
      _slots.text = (m['slots'] ?? 1).toString();
      final shift = (m['shift'] ?? {}) as Map<String, dynamic>;
      _startAt = (shift['startAt'] as Timestamp?)?.toDate();
      _endAt = (shift['endAt'] as Timestamp?)?.toDate();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<DateTime?> _pick(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date == null) return null;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _title.text.trim();
    final amt = double.tryParse(_amount.text.trim());
    final slots = int.tryParse(_slots.text.trim());
    if (title.isEmpty ||
        amt == null ||
        slots == null ||
        _startAt == null ||
        _endAt == null ||
        !_endAt!.isAfter(_startAt!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please complete all fields correctly')));
      return;
    }
    setState(() => _saving = true);
    try {
      // only allow owner to update
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('vacancies')
          .doc(widget.id)
          .update({
        'employerId': uid,
        'title': title,
        'description': _description.text.trim(),
        'category': _category,
        'wage': {'type': _type, 'amount': amt, 'currency': _currency},
        'shift': {
          'startAt': Timestamp.fromDate(_startAt!),
          'endAt': Timestamp.fromDate(_endAt!),
          'recurring': false,
        },
        'slots': slots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved ✅')));
      context.go('/employer');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete vacancy?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('vacancies')
          .doc(widget.id)
          .delete();
      if (!mounted) return;
      context.go('/employer');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext c) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Vacancy'),
        actions: [
          IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _delete)
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                      controller: _title,
                      decoration:
                          const InputDecoration(labelText: 'Job title')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField(
                    value: _category,
                    items: const [
                      DropdownMenuItem(
                          value: 'General', child: Text('General')),
                      DropdownMenuItem(value: 'Retail', child: Text('Retail')),
                      DropdownMenuItem(value: 'F&B', child: Text('F&B')),
                      DropdownMenuItem(value: 'Events', child: Text('Events')),
                      DropdownMenuItem(
                          value: 'Logistics', child: Text('Logistics')),
                    ],
                    onChanged: (v) => setState(() => _category = v as String),
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _description,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        labelText: 'Description', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: DropdownButtonFormField(
                        value: _type,
                        items: const [
                          DropdownMenuItem(
                              value: 'hourly', child: Text('Hourly')),
                          DropdownMenuItem(
                              value: 'daily', child: Text('Daily')),
                        ],
                        onChanged: (v) => setState(() => _type = v as String),
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
                          DropdownMenuItem(value: 'SGD', child: Text('SGD')),
                          DropdownMenuItem(value: 'MYR', child: Text('MYR')),
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                        ],
                        onChanged: (v) =>
                            setState(() => _currency = v as String),
                        decoration:
                            const InputDecoration(labelText: 'Currency'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.schedule),
                        label: Text(_startAt == null
                            ? 'Pick start'
                            : 'Start: ${_startAt!.toLocal()}'),
                        onPressed: () async {
                          final base = _startAt ??
                              DateTime.now().add(const Duration(hours: 1));
                          final picked = await _pick(base);
                          if (picked != null) setState(() => _startAt = picked);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(_endAt == null
                            ? 'Pick end'
                            : 'End: ${_endAt!.toLocal()}'),
                        onPressed: () async {
                          final base = _endAt ??
                              (_startAt ?? DateTime.now())
                                  .add(const Duration(hours: 4));
                          final picked = await _pick(base);
                          if (picked != null) setState(() => _endAt = picked);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _slots,
                    decoration: const InputDecoration(labelText: 'Slots'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_saving ? 'Saving...' : 'Save changes'),
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }
}

