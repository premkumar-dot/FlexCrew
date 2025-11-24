// (updated) pass role from query to SignInScreen
// lib/routing/app_router.dart
// Temporary debug router: redirects disabled for debugging.
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// Import screens used by your app (keep these imports current in your repo)
import 'package:flexcrew/features/auth/sign_in_screen.dart';
import 'package:flexcrew/features/auth/create_account_screen.dart';
import 'package:flexcrew/features/auth/forgot_password_screen.dart';
import 'package:flexcrew/features/home/worker_home.dart';
import 'package:flexcrew/features/home/employer_home.dart';
import 'package:flexcrew/features/profile/worker_profile_edit_screen.dart';
import 'package:flexcrew/features/profile/employer_profile_edit_screen.dart';
import 'package:flexcrew/features/profile/edit_profile_screen.dart';
import 'package:flexcrew/features/onboarding/worker_onboarding_screen.dart';
import 'package:flexcrew/features/onboarding/employer_onboarding_screen.dart';
import 'package:flexcrew/features/wallet/wallet_screen.dart';
import 'package:flexcrew/features/settings/settings_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  // DEBUG: do not refresh on auth changes here; keep routing deterministic for debugging.
  // NOTE: This file is temporary — restore your original redirect logic after debugging.
  routes: [
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) {
        // allow /login?role=employer or /login?role=crew
        final role = state.uri.queryParameters['role'];
        return SignInScreen(role: role);
      },
    ),
    GoRoute(path: '/create-account', name: 'create-account', builder: (_, st) {
      String? role;
      if (st.extra is Map<String, dynamic>) role = (st.extra as Map<String, dynamic>)['role'] as String?;
      role ??= st.uri.queryParameters['role'];
      return CreateAccountScreen(prefillEmail: st.uri.queryParameters['email'], role: role);
    }),
    GoRoute(path: '/forgot-password', name: 'forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(path: '/worker', name: 'worker-home', builder: (_, __) => const WorkerHomeScreen()),
    GoRoute(path: '/worker/wallet', name: 'worker-wallet', builder: (_, __) => const WalletScreen(role: 'crew')),
    GoRoute(path: '/onboarding', name: 'onboarding', builder: (_, __) => const WorkerOnboardingScreen()),
    GoRoute(path: '/employer/onboarding', name: 'employer-onboarding', builder: (_, __) => const EmployerOnboardingScreen()),
    GoRoute(path: '/worker/profile/edit', name: 'worker-profile-edit', builder: (_, __) => const WorkerProfileEditScreen()),
    GoRoute(path: '/employer', name: 'employer-home', builder: (_, __) => const EmployerHomeScreen()),
    GoRoute(path: '/employer/wallet', name: 'employer-wallet', builder: (_, __) => const WalletScreen(role: 'employer')),
    GoRoute(path: '/employer/profile/edit', name: 'employer-profile-edit', builder: (_, __) => const EmployerProfileEditScreen()),
    GoRoute(path: '/profile/edit', name: 'profile-edit', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/settings', name: 'settings', builder: (_, __) => const SettingsScreen()),
  ],
  // DEBUG: disable redirect while debugging blank screen issues
  redirect: (context, state) {
    // Print basic info to the console for debugging (visible in terminal & browser console)
    // Use state.uri (works with go_router 14.x). Avoid using state.location to be compatible.
    // ignore: avoid_print
    print('DEBUG GoRouter requested: ${state.uri}');
    return null;
  },
);
