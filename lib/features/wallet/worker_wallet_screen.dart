import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class WorkerWalletScreen extends StatelessWidget {
  const WorkerWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final orange = const Color(0xFFFF6A00);

    final txStream = FirebaseFirestore.instance
        .collection('wallet')
        .doc(user.uid)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: txStream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('No transactions yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final d = docs[i].data();
              final amount = (d['amount'] ?? 0).toDouble();
              final type = (d['type'] ?? 'earn') as String; // earn|spend
              final note = (d['note'] ?? '') as String;
              final sign = type == 'spend' ? '-' : '+';
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                tileColor: const Color(0xFFFDFDFD),
                title: Text(note.isEmpty
                    ? (type == 'spend' ? 'Spending' : 'Earning')
                    : note),
                trailing: Text(
                  '$sign\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: type == 'spend' ? Colors.red : orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

