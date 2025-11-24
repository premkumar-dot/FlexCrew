import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flexcrew/widgets/app_logo.dart';
import 'package:flexcrew/utils/nav_helpers.dart';
import 'package:flexcrew/services/navigation_service.dart';\r\n
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Defer navigation until after first frame so Scaffold is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      GoRouter.of(context).go('/login');
      return;
    }

    // Use centralized helper to resolve persisted role and navigate
    await navigateToPersistedRole(context, fallback: 'worker');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: AppLogo(height: 600, showTagline: false)),
    );
  }
}


