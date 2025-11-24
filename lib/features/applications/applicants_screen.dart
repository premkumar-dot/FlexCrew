import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ApplicantsScreen extends StatelessWidget {
  final String vacancyId;
  const ApplicantsScreen({super.key, required this.vacancyId});

  Future<void> _setStatus(
      BuildContext context, String appId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('applications')
          .doc(appId)
          .update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Status → $status')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = FirebaseFirestore.instance
        .collection('applications')
        .where('vacancyId', isEqualTo: vacancyId)
        .orderBy('createdAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Applicants')),
      body: StreamBuilder<QuerySnapshot>(
        stream: q.snapshots(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(
                child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: ${snap.error}'),
            ));
          }
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final docs = snap.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('No applicants yet'));

          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = docs[i];
              final m = d.data() as Map<String, dynamic>;
              final status = (m['status'] ?? 'sent') as String;
              final workerId = (m['workerId'] ?? '') as String;

              return ListTile(
                title: Text('Worker: $workerId'),
                subtitle: Text('Status: $status'),
                trailing: Wrap(spacing: 6, children: [
                  OutlinedButton(
                    onPressed: () => _setStatus(context, d.id, 'viewed'),
                    child: const Text('Viewed'),
                  ),
                  OutlinedButton(
                    onPressed: () => _setStatus(context, d.id, 'shortlisted'),
                    child: const Text('Shortlist'),
                  ),
                  FilledButton(
                    onPressed: () => _setStatus(context, d.id, 'accepted'),
                    child: const Text('Accept'),
                  ),
                  TextButton(
                    onPressed: () => _setStatus(context, d.id, 'declined'),
                    child: const Text('Decline'),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

