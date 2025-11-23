import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flexcrew/routing/router_globals.dart';
import 'package:flexcrew/services/navigation_service.dart';

String _normalizeRole(String? raw) {
  final r = (raw ?? '').toString().trim().toLowerCase();
  if (r == 'employer') return 'employer';
  return 'worker';
}

/// Resolve persisted role for current user and navigate to the appropriate home.
/// Returns the resolved role ('employer'|'worker') or null if not signed in.
Future<String?> navigateToPersistedRole({String fallback = 'worker'}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    // not signed in — caller should handle routing to /login
    return null;
  }

  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final raw = doc.data()?['role'] as String?;
    final role = _normalizeRole((raw != null && raw.isNotEmpty) ? raw : fallback);

    // persist normalized role back to users/{uid} (best-effort)
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'role': role}, SetOptions(merge: true));
    } catch (_) {}

    final target = role == 'employer' ? '/employer' : '/worker';

    // Prefer global appRouter
    try {
      if (appRouter.location != target) appRouter.go(target);
    } catch (_) {
      // fallback to NavigationService (which resolves router from rootNavigatorKey)
      try {
        final nav = NavigationService.instance;
        nav.go(target);
      } catch (_) {}
    }

    return role;
  } catch (e) {
    // on error fall back to worker
    try {
      appRouter.go('/worker');
    } catch (_) {
      try {
        NavigationService.instance.go('/worker');
      } catch (_) {}
    }
    return 'worker';
  }
}
