import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/notification_bell.dart';

class EmployerHome extends StatelessWidget {
  const EmployerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final q = FirebaseFirestore.instance.collection('vacancies').where('employerId', isEqualTo: uid);
    final appBarBg = Theme.of(context).colorScheme.primary;
    final appBarFg = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        title: const Text('Employer Home'),
        actions: const [NotificationBell()],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => GoRouter.of(context).go('/employer/vacancy/new'),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No vacancies yet.'));

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final d = docs[index];
              final m = d.data() as Map<String, dynamic>;
              final title = (m['title'] as String?) ?? 'Vacancy';
              final rate = m['ratePerHour'] ?? (m['wage'] is Map ? m['wage']['amount'] : null);
              final location = (m['location'] as String?) ?? (m['locationText'] as String?) ?? (m['address'] as String?) ?? '';
              final dress = (m['dressCode'] as String?) ?? (m['dress'] as String?) ?? '';
              final slots = (m['slots'] is num) ? (m['slots'] as num).toInt() : int.tryParse((m['slots'] ?? '0').toString()) ?? 0;
              final status = (m['status'] as String?) ?? 'open';

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text(status, style: Theme.of(context).textTheme.bodySmall),
                          if (location.isNotEmpty) const SizedBox(height: 6),
                          if (location.isNotEmpty)
                            Row(children: [
                              const Icon(Icons.location_on, size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Text(location, style: Theme.of(context).textTheme.bodySmall)),
                            ]),
                        ]),
                      ),

                      // Right-side summary (dress + edit)
                      Column(mainAxisSize: MainAxisSize.min, children: [
                        if (dress.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              const Icon(Icons.checkroom, size: 14),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 160),
                                child: Text(dress, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          ),
                        IconButton(
                          icon: const Icon(Icons.edit),
                          tooltip: 'Edit vacancy',
                          onPressed: () => GoRouter.of(context).go('/employer/vacancy/${d.id}/edit', extra: m),
                        ),
                      ]),
                    ]),
                    const SizedBox(height: 10),

                    // Chips row
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      if (rate != null) Chip(label: Text('\$${rate.toString()} /hr')),
                      if (location.isNotEmpty) Chip(label: Text(location)),
                      if (dress.isNotEmpty) Chip(label: Text(dress)),
                      Chip(label: Text('Slots: $slots')),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
