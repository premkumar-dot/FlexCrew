import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Replace with your generated Firebase options (created by `flutterfire configure`)
import 'firebase_options.dart';

import 'widgets/web_style_splash.dart';
import 'theme/app_theme.dart';

// Router: use the app router and set the global router variable
import 'routing/app_router.dart' as ar;
import 'routing/router_globals.dart' as rg;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Ensure the global router reference is assigned before the app starts.
  rg.appRouter = ar.appRouter;

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'FlexCrew',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: ar.appRouter,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (kIsWeb) const WebStyleSplash(),
          ],
        );
      },
    );
  }
}
