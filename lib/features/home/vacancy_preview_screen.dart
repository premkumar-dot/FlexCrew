import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class VacancyPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> vacancy;
  const VacancyPreviewScreen({super.key, required this.vacancy});

  static final _dateFmt = DateFormat.yMMMd().add_jm();

  String _formatTs(dynamic v) {
    if (v == null) return '—';
    if (v is Timestamp) return _dateFmt.format(v.toDate());
    if (v is DateTime) return _dateFmt.format(v);
    return v.toString();
  }

  String _readLocation(Map<String, dynamic> v) {
    final l = (v['location'] as String?) ?? '';
    if (l.trim().isNotEmpty) return l.trim();
    final locMap = v['location'];
    if (locMap is Map && locMap['name'] is String) return locMap['name'].toString();
    return '';
  }

  String _readDress(Map<String, dynamic> v) {
    return ((v['dressCode'] as String?) ?? '').toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final title = vacancy['title'] as String? ?? 'Vacancy';
    final desc = vacancy['description'] as String? ?? '';
    final rate = vacancy['ratePerHour'];
    final slots = vacancy['slots']?.toString() ?? 'N/A';
    final startAt = vacancy['startAt'];
    final endAt = vacancy['endAt'];
    final deadline = vacancy['applicationDeadline'];
    final tags = vacancy['tags'] as List<dynamic>? ?? [];
    final location = _readLocation(vacancy);
    final dress = _readDress(vacancy);

    return Scaffold(
      appBar: AppBar(title: const Text('Preview Vacancy')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  if (desc.isNotEmpty) Text(desc),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    // Rate
                    if (rate != null) Chip(label: Text('\$${rate.toString()} /hr')),

                    // Location
                    if (location.isNotEmpty) Chip(label: Text(location)),

                    // Dress code
                    if (dress.isNotEmpty) Chip(label: Text(dress)),

                    // Slots (after location and dress)
                    Chip(label: Text('Slots: $slots')),

                    if (tags.isNotEmpty) Chip(label: Text('Tags: ${tags.join(', ')}')),
                  ]),
                  const SizedBox(height: 12),
                  // Explicit Location & Dress list items for preview clarity
                  if (location.isNotEmpty) ListTile(leading: const Icon(Icons.location_on), title: const Text('Location'), subtitle: Text(location)),
                  if (dress.isNotEmpty) ListTile(leading: const Icon(Icons.checkroom), title: const Text('Dress code'), subtitle: Text(dress)),
                  const SizedBox(height: 8),
                  ListTile(leading: const Icon(Icons.event), title: const Text('Start'), subtitle: Text(_formatTs(startAt))),
                  ListTile(leading: const Icon(Icons.event), title: const Text('End'), subtitle: Text(_formatTs(endAt))),
                  ListTile(leading: const Icon(Icons.schedule), title: const Text('Apply By'), subtitle: Text(_formatTs(deadline))),
                ]),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm & Save'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Edit')),
          ]),
        ),
      ),
    );
  }
}
