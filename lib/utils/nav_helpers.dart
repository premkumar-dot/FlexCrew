import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flexcrew/routing/router_globals.dart' as rg;
import 'package:flexcrew/services/navigation_service.dart';
import 'package:flexcrew/utils/navigation_by_role.dart' as byrole;

/// Only go to /login if there is NO signed-in user.
void goLoginIfSignedOut(BuildContext context) {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    try {
      rg.appRouter.go('/login');
    } catch (_) {
      try {
        NavigationService.instance.go('/login');
      } catch (_) {}
    }
  }
}

/// Proper logout flow (sign out, then go /login).
Future<void> goLogout(BuildContext context) async {
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}
  try {
    rg.appRouter.go('/login');
  } catch (_) {
    try {
      NavigationService.instance.go('/login');
    } catch (_) {}
  }
}

/// Forwarding wrapper to keep the original helper API.
Future<String?> navigateToPersistedRole(BuildContext? context, {String fallback = 'worker'}) {
  return byrole.navigateToPersistedRole(context, fallback: fallback);
}

