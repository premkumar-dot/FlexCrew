import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flexcrew/utils/nav_helpers.dart';

/// Logs all route changes and prevents unnecessary `/login` pushes while signed in.
/// Also suppresses SnackBar errors when no Scaffold is available yet.
class RouteLogger extends NavigatorObserver {
  final bool showSnack;
  RouteLogger({this.showSnack = true});

  void _toast(BuildContext? context, String msg) {
    // Always print to console
    // ignore: avoid_print
    print('🧭 RouteLogger: $msg');

    if (!showSnack || context == null) return;

    // Only show SnackBar if a ScaffoldMessenger is actually mounted
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger != null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(msg, style: const TextStyle(fontSize: 13)),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.black87,
          ),
        );
    }
  }

  void _maybeBlockLogin(Route<dynamic> route) {
    final name = route.settings.name;
    final user = FirebaseAuth.instance.currentUser;

    if (name == '/login' && user != null) {
      // We’re signed in; prevent redundant /login pushes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = navigator?.context;
        if (ctx != null) {
          _toast(ctx, 'Blocked /login (signed in) — resolving role...');
          // Delegate navigation to centralized helper (async)
          navigateToPersistedRole(ctx, fallback: 'worker');
        }
      });
    }
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final ctx = navigator?.context;
    _toast(ctx,
        '→ Pushed: ${route.settings.name ?? route.settings.arguments ?? route}');
    _maybeBlockLogin(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final ctx = navigator?.context;
    _toast(ctx,
        '⤴️ Replaced: ${oldRoute?.settings.name ?? ''} → ${newRoute?.settings.name ?? ''}');
    if (newRoute != null) _maybeBlockLogin(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _toast(navigator?.context, '← Popped: ${route.settings.name ?? route}');
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _toast(navigator?.context, '✖️ Removed: ${route.settings.name ?? ''}');
    super.didRemove(route, previousRoute);
  }
}
