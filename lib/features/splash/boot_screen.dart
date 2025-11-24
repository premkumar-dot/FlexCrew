import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flexcrew/utils/nav_helpers.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});
  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Safety net: even if redirect logic changes, leave splash quickly.
    _timer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      // Resolve role asynchronously and navigate.
      () async {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) context.go('/login');
          return;
        }
        if (mounted) await navigateToPersistedRole(context, fallback: 'worker');
      }();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Locked splash UI
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/logo/flexcrew_logo.png',
              height: 120,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            const Text(
              'Starting...',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'This screen is locked. Navigation is handled by the router.',
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}
