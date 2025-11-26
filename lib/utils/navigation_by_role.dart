import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flexcrew/routing/router_globals.dart' as rg;
import 'package:flexcrew/services/navigation_service.dart';

String _normalizeRole(String? raw) {
  final r = (raw ?? '').toString().trim().toLowerCase();
  if (r == 'employer') return 'employer';
  return 'worker';
}

/// Resolve persisted role for current user and navigate to the appropriate home.
/// Accepts an optional BuildContext to preserve the calling API.
Future<String?> navigateToPersistedRole(BuildContext? context, {String fallback = 'worker'}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint('navigateToPersistedRole: no user signed in');
    return null;
  }

  try {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final raw = doc.data()?['role'] as String?;
    final role = _normalizeRole((raw != null && raw.isNotEmpty) ? raw : fallback);

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'role': role}, SetOptions(merge: true));
    } catch (_) {}

    final target = role == 'employer' ? '/employer' : '/worker';

    // Prefer global appRouter, fallback to NavigationService
    try {
      rg.appRouter.go(target);
    } catch (_) {
      try {
        NavigationService.instance.go(target);
      } catch (_) {}
    }

    return role;
  } catch (e, st) {
    debugPrint('navigateToPersistedRole: error resolving role: $e\n$st');
    try {
      rg.appRouter.go('/worker');
    } catch (_) {
      try {
        NavigationService.instance.go('/worker');
      } catch (_) {}
    }
    return 'worker';
  }
}
