import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Replace with your generated Firebase options (created by `flutterfire configure`)
import 'firebase_options.dart';

import 'widgets/web_style_splash.dart';
import 'features/home/worker_home.dart';
import 'features/conversations/conversations.dart';
import 'features/auth/sign_in_screen.dart';
import 'theme/app_theme.dart';
import 'features/wallet/wallet_screen.dart';
import 'features/profile/edit_profile_screen.dart';
import 'features/settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the centralized AppTheme so all widgets follow the brand orange color
    return MaterialApp(
      title: 'FlexCrew',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            if (kIsWeb) const WebStyleSplash(),
          ],
        );
      },
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (!snap.hasData) {
            return const SignInScreen();
          }
          return const WorkerHomeScreen();
        },
      ),
      routes: {
        '/home': (_) => const WorkerHomeScreen(),
        '/conversations': (_) => const ConversationsListScreen(),
        '/wallet': (_) => const WalletScreen(role: 'crew'),
        '/profile/edit': (_) => const EditProfileScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}
