// Notification bell uses the global router via the rg alias and falls back to NavigationService.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flexcrew/routing/router_globals.dart' as rg;
import 'package:flexcrew/services/navigation_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  Future<String> _resolveRoleForUid(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = doc.data()?['role'] as String? ?? '';
      final role = raw.trim().toLowerCase();
      if (role == 'employer') return 'employer';
    } catch (_) {}
    return 'worker';
  }

  String _normalizeRoute(String raw) {
    if (raw.isEmpty) return '';
    return raw.startsWith('/') ? raw : '/$raw';
  }

  Future<void> _navigateForNotification(BuildContext ctx, Map<String, dynamic>? data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      try {
        rg.appRouter.go('/login');
      } catch (_) {
        try {
          NavigationService.instance.go('/login');
        } catch (_) {}
      }
      return;
    }

    final routeRaw = (data?['route'] as String?) ?? '';
    if (routeRaw.isEmpty) {
      try {
        rg.appRouter.go('/notifications');
      } catch (_) {
        try {
          NavigationService.instance.go('/notifications');
        } catch (_) {}
      }
      return;
    }

    final route = _normalizeRoute(routeRaw);
    if (route.startsWith('/worker') || route.startsWith('/employer')) {
      try {
        rg.appRouter.go(route);
      } catch (_) {
        try {
          NavigationService.instance.go(route);
        } catch (_) {}
      }
      return;
    }

    final role = await _resolveRoleForUid(uid);
    final base = role == 'employer' ? '/employer' : '/worker';
    final target = route.startsWith('/') ? '$base$route' : '$base/$route';
    try {
      rg.appRouter.go(target);
    } catch (_) {
      try {
        NavigationService.instance.go(target);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        icon: const Icon(Icons.notifications_none),
        onPressed: () {
          try {
            rg.appRouter.go('/login');
          } catch (_) {
            try {
              NavigationService.instance.go('/login');
            } catch (_) {}
          }
        },
        tooltip: 'Notifications',
      );
    }

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return IconButton(icon: const Icon(Icons.notifications_none), onPressed: null, tooltip: 'Notifications');
        }
        final docs = snap.data!.docs;
        final unreadCount = docs.where((d) => (d.data()['read'] as bool?) != true).length;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () async {
                if (!ctx.mounted) return;
                await showModalBottomSheet(
                  context: ctx,
                  builder: (sheetCtx) {
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final doc = docs[i];
                        final data = doc.data();
                        final title = data['title'] as String? ?? 'Notification';
                        final body = data['body'] as String? ?? '';
                        final read = (data['read'] as bool?) ?? false;
                        return ListTile(
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: read ? null : Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const SizedBox(width: 6, height: 6)),
                          onTap: () async {
                            Navigator.of(sheetCtx).pop();
                            try {
                              await FirebaseFirestore.instance.collection('notifications').doc(doc.id).set({'read': true}, SetOptions(merge: true));
                            } catch (_) {}
                            await _navigateForNotification(ctx, data);
                          },
                        );
                      },
                    );
                  },
                );
              },
              tooltip: 'Notifications',
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
