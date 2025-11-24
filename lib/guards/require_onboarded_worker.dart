import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RequireOnboardedWorker extends StatelessWidget {
  const RequireOnboardedWorker({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/login');
      });
      return const _BlockingScreen(message: 'Redirecting to sign in…');
    }

    final uid = user.uid;
    final doc = FirebaseFirestore.instance.collection('users').doc(uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: doc.snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const _BlockingScreen(message: 'Checking onboarding…');
        }
        final data = snap.data!.data() ?? {};
        final done = data['onboardingComplete'] == true;

        if (!done) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/onboarding');
          });
          return const _BlockingScreen(message: 'Onboarding required…');
        }
        return child;
      },
    );
  }
}

class _BlockingScreen extends StatelessWidget {
  const _BlockingScreen({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message),
        ]),
      ),
    );
  }
}

