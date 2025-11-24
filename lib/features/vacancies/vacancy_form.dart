// VacancyForm dialog helper + widget
// - Added application deadline (date + optional time) to the form and payload.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// VacancyForm dialog helper + widget
/// Usage:
///   await showVacancyFormDialog(context); // create
///   await showVacancyFormDialog(context, editId: id, initial: data); // edit
Future<bool?> showVacancyFormDialog(BuildContext context, {String? editId, Map<String, dynamic>? initial}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: SizedBox(width: 740, child: VacancyForm(editId: editId, initial: initial)),
    ),
  );
}

class VacancyForm extends StatefulWidget {
  final String? editId;
  final Map<String, dynamic>? initial;
  const VacancyForm({super.key, this.editId, this.initial});

  @override
  State<VacancyForm> createState() => _VacancyFormState();
}

class _VacancyFormState extends State<VacancyForm> {
  final _formKey = GlobalKey<FormState>();
  final _db = FirebaseFirestore.instance;

  // Controllers
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _slotsCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _dressCtrl;
  late final TextEditingController _rateCtrl;

  DateTime? _startDate;
  DateTime? _endDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  // New: application deadline (date + optional time)
  DateTime? _applicationDeadlineDate;
  TimeOfDay? _applicationDeadlineTime;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial ?? {};

    _titleCtrl = TextEditingController(text: (init['title'] as String?) ?? '');
    _descCtrl = TextEditingController(text: (init['description'] as String?) ?? '');
    _slotsCtrl = TextEditingController(text: ((init['slots'] ?? 1).toString()));
    _locationCtrl = TextEditingController(text: (init['location'] as String?) ?? '');
    _dressCtrl = TextEditingController(text: (init['dressCode'] as String?) ?? '');
    _rateCtrl = TextEditingController(text: (init['ratePerHour']?.toString()) ?? '');

    // populate date/time if provided as Timestamp
    if (init['startAt'] is Timestamp) {
      final dt = (init['startAt'] as Timestamp).toDate();
      _startDate = DateTime(dt.year, dt.month, dt.day);
      _startTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    } else if (init['startDate'] is Timestamp) {
      _startDate = (init['startDate'] as Timestamp).toDate();
    }

    if (init['endAt'] is Timestamp) {
      final dt = (init['endAt'] as Timestamp).toDate();
      _endDate = DateTime(dt.year, dt.month, dt.day);
      _endTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    } else if (init['endDate'] is Timestamp) {
      _endDate = (init['endDate'] as Timestamp).toDate();
    }

    // applicationDeadline may be stored as Timestamp
    if (init['applicationDeadline'] is Timestamp) {
      final dt = (init['applicationDeadline'] as Timestamp).toDate();
      _applicationDeadlineDate = DateTime(dt.year, dt.month, dt.day);
      _applicationDeadlineTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _slotsCtrl.dispose();
    _locationCtrl.dispose();
    _dressCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(BuildContext ctx, bool start) async {
    final now = DateTime.now();
    final initial = start ? (_startDate ?? now) : (_endDate ?? (_startDate ?? now));
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _pickTime(BuildContext ctx, bool start) async {
    final initial = start ? (_startTime ?? const TimeOfDay(hour: 9, minute: 0)) : (_endTime ?? const TimeOfDay(hour: 17, minute: 0));
    final picked = await showTimePicker(context: ctx, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (start) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  Future<void> _pickApplicationDeadlineDate(BuildContext ctx) async {
    final now = DateTime.now();
    final initial = _applicationDeadlineDate ?? now;
    final picked = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _applicationDeadlineDate = picked);
  }

  Future<void> _pickApplicationDeadlineTime(BuildContext ctx) async {
    final initial = _applicationDeadlineTime ?? const TimeOfDay(hour: 23, minute: 59);
    final picked = await showTimePicker(context: ctx, initialTime: initial);
    if (picked == null) return;
    setState(() => _applicationDeadlineTime = picked);
  }

  String _fmtDate(DateTime? d) => d == null ? 'Not set' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _fmtTime(TimeOfDay? t) => t == null ? 'Not set' : t.format(context);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final slots = int.tryParse(_slotsCtrl.text.trim()) ?? 1;
    final location = _locationCtrl.text.trim();
    final dress = _dressCtrl.text.trim();
    final rate = double.tryParse(_rateCtrl.text.trim());

    // combine date+time
    DateTime? startAt;
    DateTime? endAt;
    DateTime? applicationDeadline;
    if (_startDate != null) {
      startAt = DateTime(_startDate!.year, _startDate!.month, _startDate!.day, _startTime?.hour ?? 0, _startTime?.minute ?? 0);
    }
    if (_endDate != null) {
      endAt = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, _endTime?.hour ?? 0, _endTime?.minute ?? 0);
    }
    if (_applicationDeadlineDate != null) {
      applicationDeadline = DateTime(
        _applicationDeadlineDate!.year,
        _applicationDeadlineDate!.month,
        _applicationDeadlineDate!.day,
        _applicationDeadlineTime?.hour ?? 23,
        _applicationDeadlineTime?.minute ?? 59,
      );
    }

    if (startAt != null && endAt != null && endAt.isBefore(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End must not be before start')));
      return;
    }
    if (applicationDeadline != null && startAt != null && applicationDeadline.isAfter(startAt)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application deadline should be before start')));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    final payload = <String, dynamic>{
      'title': title,
      'description': description.isNotEmpty ? description : null,
      'location': location.isNotEmpty ? location : null,
      'dressCode': dress.isNotEmpty ? dress : null,
      'slots': slots,
      'ratePerHour': rate,
      'employerId': uid,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (startAt != null) payload['startAt'] = Timestamp.fromDate(startAt);
    if (endAt != null) payload['endAt'] = Timestamp.fromDate(endAt);
    if (applicationDeadline != null) payload['applicationDeadline'] = Timestamp.fromDate(applicationDeadline);

    setState(() => _saving = true);
    try {
      if (widget.editId == null) {
        payload['status'] = 'open';
        payload['createdAt'] = FieldValue.serverTimestamp();
        await _db.collection('vacancies').add(payload);
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vacancy posted')));
        }
      } else {
        await _db.collection('vacancies').doc(widget.editId).set(payload, SetOptions(merge: true));
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vacancy updated')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editId != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Text(isEdit ? 'Edit Vacancy' : 'Post Vacancy', style: Theme.of(context).textTheme.titleLarge)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop(false)),
          ]),
          const SizedBox(height: 8),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.title), labelText: 'Title', hintText: 'e.g. Event steward (evening)'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.description), labelText: 'Description', hintText: 'Brief description of the role'),
                  minLines: 2,
                  maxLines: 5,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text('Start\n${_fmtDate(_startDate)}', textAlign: TextAlign.center),
                        onPressed: () => _pickDate(context, true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text('Start time\n${_fmtTime(_startTime)}', textAlign: TextAlign.center),
                        onPressed: () => _pickTime(context, true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text('End\n${_fmtDate(_endDate)}', textAlign: TextAlign.center),
                        onPressed: () => _pickDate(context, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time),
                        label: Text('End time\n${_fmtTime(_endTime)}', textAlign: TextAlign.center),
                        onPressed: () => _pickTime(context, false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Application deadline controls
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_busy),
                        label: Text('Apply by\n${_fmtDate(_applicationDeadlineDate)}', textAlign: TextAlign.center),
                        onPressed: () => _pickApplicationDeadlineDate(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time_filled),
                        label: Text('Deadline time\n${_fmtTime(_applicationDeadlineTime)}', textAlign: TextAlign.center),
                        onPressed: () => _pickApplicationDeadlineTime(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.place), labelText: 'Location', hintText: 'Venue or address'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _dressCtrl,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.checkroom), labelText: 'Dress code', hintText: 'e.g. smart casual / uniform provided'),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rateCtrl,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.attach_money), labelText: 'Rate / hour', hintText: 'e.g. 15.00'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 140,
                    child: TextFormField(
                      controller: _slotsCtrl,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.group), labelText: 'Slots'),
                      keyboardType: TextInputType.number,
                      validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Must be > 0' : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
                    label: Text(isEdit ? 'Save' : 'Post'),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
