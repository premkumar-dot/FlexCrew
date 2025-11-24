import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({super.key});

  Query<Map<String, dynamic>> _query() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100);
  }

  Future<void> _markAllRead() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final batch = FirebaseFirestore.instance.batch();
    final snap = await FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .get();
    for (final d in snap.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read',
                style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _query().snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('You’re all caught up.'));
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final m = docs[i].data();
              final read = m['read'] == true;
              final title = m['title'] as String? ?? 'Notification';
              final body = m['body'] as String? ?? '';
              final ts = (m['createdAt'] as Timestamp?)?.toDate();
              return ListTile(
                leading: Icon(
                    read ? Icons.notifications : Icons.notifications_active),
                title: Text(title,
                    style: TextStyle(
                        fontWeight:
                            read ? FontWeight.normal : FontWeight.w600)),
                subtitle: Text(body),
                trailing: ts != null
                    ? Text(
                        '${ts.month}/${ts.day} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}')
                    : null,
                onTap: () => docs[i].reference.update({'read': true}),
              );
            },
          );
        },
      ),
    );
  }
}

