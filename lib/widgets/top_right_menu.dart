import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TopRightMenu extends StatelessWidget {
  final bool isEmployer; // false = Crew
  const TopRightMenu({super.key, this.isEmployer = false});

  Future<bool> _resolveIsEmployer() async {
    // If caller explicitly set isEmployer true, respect it immediately.
    if (isEmployer) return true;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = doc.data()?['role'] as String? ?? '';
      final role = raw.trim().toLowerCase();
      return role == 'employer';
    } catch (_) {
      // On any error, treat as worker (safe fallback)
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Settings',
      onSelected: (v) async {
        // Determine authoritative role (best-effort). If `isEmployer` was true,
        // _resolveIsEmployer() will short-circuit to true.
        final resolvedIsEmployer = await _resolveIsEmployer();

        switch (v) {
          case 'wallet':
            context.push(resolvedIsEmployer ? '/employer/wallet' : '/worker/wallet');
            break;
          case 'profile':
            context.push(resolvedIsEmployer ? '/employer/profile' : '/worker/profile/edit');
            break;
          case 'logout':
            await FirebaseAuth.instance.signOut();
            if (context.mounted) context.go('/login');
            break;
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'wallet', child: Text('My Wallet')),
        PopupMenuItem(value: 'profile', child: Text('Profile')),
        PopupMenuItem(value: 'logout', child: Text('Logout')),
      ],
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}

