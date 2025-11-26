import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Root navigator key used to resolve the app's GoRouter via context.
/// Keep this file tiny to avoid circular imports.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Global app router instance. Set in `main.dart` after the router is built.
late GoRouter appRouter;

