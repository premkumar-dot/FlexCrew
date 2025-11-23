import 'package:firebase_auth/firebase_auth.dart';
import 'package:flexcrew/routing/router_globals.dart';
import 'package:flexcrew/services/navigation_service.dart';

/// Only go to /login if there is NO signed-in user.
void goLoginIfSignedOut() {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    try {
      appRouter.go('/login');
    } catch (_) {
      try {
        NavigationService.instance.go('/login');
      } catch (_) {}
    }
  }
}

/// Proper logout flow (sign out, then go /login).
Future<void> goLogout() async {
  try {
    await FirebaseAuth.instance.signOut();
  } catch (_) {}
  try {
    appRouter.go('/login');
  } catch (_) {
    try {
      NavigationService.instance.go('/login');
    } catch (_) {}
  }
}
