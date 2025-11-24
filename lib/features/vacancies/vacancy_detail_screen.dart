import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class VacancyDetailScreen extends StatelessWidget {
  final String id;
  const VacancyDetailScreen({super.key, required this.id});

  Future<void> _apply(BuildContext c, Map<String, dynamic> m) async {
    final user = FirebaseAuth.instance.currentUser!;
    await FirebaseFirestore.instance.collection('applications').add({
      'vacancyId': id,
      'workerId': user.uid,
      'employerId': m['employerId'],
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(c)
        .showSnackBar(const SnackBar(content: Text('Interest sent!')));
  }

  @override
  Widget build(BuildContext c) {
    final ref = FirebaseFirestore.instance.collection('vacancies').doc(id);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Vacancy')),
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.get(),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final m = snap.data!.data() as Map<String, dynamic>;
          final appQuery = FirebaseFirestore.instance
              .collection('applications')
              .where('vacancyId', isEqualTo: id)
              .where('workerId', isEqualTo: uid)
              .limit(1);

          return StreamBuilder<QuerySnapshot>(
            stream: appQuery.snapshots(),
            builder: (ctx2, appSnap) {
              final already = (appSnap.data?.docs.isNotEmpty ?? false);
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m['title'] ?? '',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(m['description'] ?? ''),
                      const Spacer(),
                      if (already)
                        const Text('You have already expressed interest.',
                            style: TextStyle(fontStyle: FontStyle.italic))
                      else
                        ElevatedButton(
                            onPressed: () => _apply(c, m),
                            child: const Text('Express Interest')),
                    ]),
              );
            },
          );
        },
      ),
    );
  }
}

