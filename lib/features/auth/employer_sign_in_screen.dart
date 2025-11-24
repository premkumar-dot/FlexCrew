import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmployerSignInScreen extends StatelessWidget {
  const EmployerSignInScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFFFF6A00);
    return Scaffold(
      appBar: AppBar(title: const Text('Employer sign in'), backgroundColor: brand),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Sign in as an employer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: brand),
              onPressed: () {
                // Navigate to the shared login screen and provide role query param for prefill
                context.go('/login?role=employer');
              },
              child: const Text('Go to sign in'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go('/create-account?role=employer'),
              child: const Text('Create employer account'),
            ),
          ]),
        ),
      ),
    );
  }
}
