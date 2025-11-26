// Minimal NavigationService compatible with go_router v14+.
// Uses the global `rg.appRouter` instance (router-first).
import 'package:go_router/go_router.dart';
import 'package:flexcrew/routing/router_globals.dart' as rg;

/// Minimal NavigationService compatible with go_router v14+.
/// Uses the global `rg.appRouter` instance (router-first).
class NavigationService {
  NavigationService._();
  static final NavigationService instance = NavigationService._();

  GoRouter? get _maybeRouter {
    try {
      return rg.appRouter;
    } catch (_) {
      return null;
    }
  }

  void push(String location, {Object? extra}) {
    final r = _maybeRouter;
    if (r != null) r.push(location, extra: extra);
  }

  void go(String location, {Object? extra}) {
    final r = _maybeRouter;
    if (r != null) r.go(location, extra: extra);
  }

  void pushNamed(String name, {Object? extra}) {
    final r = _maybeRouter;
    if (r != null) r.pushNamed(name, extra: extra);
  }

  void goNamed(String name, {Object? extra}) {
    final r = _maybeRouter;
    if (r != null) r.goNamed(name, extra: extra);
  }
}

