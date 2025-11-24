import 'package:flutter/widgets.dart';

/// Root navigator key used to resolve the app's GoRouter via context.
/// Keep this file tiny to avoid circular imports.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
