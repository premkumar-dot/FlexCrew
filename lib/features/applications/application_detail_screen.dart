import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final String id;
  const ApplicationDetailScreen({super.key, required this.id});
  @override
  State<ApplicationDetailScreen> createState() =>
      _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  bool _busy = false;

  Future<void> _withdraw() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref =
          FirebaseFirestore.instance.collection('applications').doc(widget.id);
      final snap = await ref.get();
      final m = snap.data() as Map<String, dynamic>?;

      if (m == null || m['workerId'] != uid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Not allowed')));
        setState(() => _busy = false);
        return;
      }

      await ref.update({
        'status': 'withdrawn',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Withdrawn ✅')));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref =
        FirebaseFirestore.instance.collection('applications').doc(widget.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Application')),
      body: FutureBuilder<DocumentSnapshot>(
        future: ref.get(),
        builder: (ctx, snap) {
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          final m = snap.data!.data() as Map<String, dynamic>?;
          if (m == null)
            return const Center(child: Text('Application not found'));

          final status = (m['status'] ?? 'sent') as String;
          return Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vacancy: ${m['vacancyId']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Status: $status'),
              const Spacer(),
              if (status != 'withdrawn' && status != 'accepted')
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _busy ? null : _withdraw,
                    icon: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.undo),
                    label: Text(_busy ? 'Withdrawing...' : 'Withdraw interest'),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

