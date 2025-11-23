import 'package:go_router/go_router.dart';
import 'package:flexcrew/routing/router_globals.dart';

/// Minimal NavigationService compatible with go_router v14+.
/// Prefers the global `appRouter` and falls back to resolving the router
/// from `rootNavigatorKey.currentContext`.
class NavigationService {
  NavigationService._();
  static final NavigationService instance = NavigationService._();

  GoRouter? get _maybeRouter {
    // Prefer the global router instance when available (router-first).
    try {
      return appRouter;
    } catch (_) {}
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return null;
    try {
      return GoRouter.of(ctx);
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
