// lib/routing/app_router.dart
// Router configuration — simplified app router with embedded login.
// Admin routes intentionally removed from this build.
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

// App screens
import 'package:flexcrew/features/auth/create_account_screen.dart';
import 'package:flexcrew/features/auth/forgot_password_screen.dart';
import 'package:flexcrew/features/auth/login_screen.dart';
import 'package:flexcrew/features/home/worker_home.dart';
import 'package:flexcrew/features/home/employer_home.dart';
import 'package:flexcrew/features/home/vacancy_create_screen.dart';
import 'package:flexcrew/features/home/vacancy_edit_screen.dart';
import 'package:flexcrew/features/profile/worker_profile_edit_screen.dart';
import 'package:flexcrew/features/profile/employer_profile_edit_screen.dart';
import 'package:flexcrew/features/profile/edit_profile_screen.dart';
import 'package:flexcrew/features/onboarding/worker_onboarding_screen.dart';
import 'package:flexcrew/features/onboarding/employer_onboarding_screen.dart';
import 'package:flexcrew/features/wallet/wallet_screen.dart';
import 'package:flexcrew/features/settings/settings_screen.dart';
import 'package:flexcrew/features/splash/boot_screen.dart';
import 'package:flexcrew/guards/require_onboarded_worker.dart';

// NOTE: Admin screens intentionally omitted in this build.

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    // Splash / boot: resolves auth state and navigates to external auth or app home.
    GoRoute(path: '/', name: 'boot', builder: (_, __) => const BootScreen()),

    // External auth entrypoint: point to the embedded login screen for this app.
    GoRoute(
      path: '/auth-external',
      name: 'auth-external',
      builder: (_, __) {
        return const LoginScreen();
      },
    ),

    // Account flows that remain in-app (profile creation, forgot password etc.)
    GoRoute(
      path: '/create-account',
      name: 'create-account',
      builder: (_, st) {
        String? role;
        if (st.extra is Map<String, dynamic>) role = (st.extra as Map<String, dynamic>)['role'] as String?;
        role ??= st.uri.queryParameters['role'];
        return CreateAccountScreen(prefillEmail: st.uri.queryParameters['email'], role: role);
      },
    ),
    GoRoute(path: '/forgot-password', name: 'forgot-password', builder: (_, __) => const ForgotPasswordScreen()),

    // Primary app routes - IMPROVEMENT: Wrap worker routes with onboarding guard
    GoRoute(
      path: '/worker',
      name: 'worker-home',
      builder: (_, __) => const RequireOnboardedWorker(
        child: WorkerHomeScreen(),
      ),
    ),
    GoRoute(
      path: '/worker/wallet',
      name: 'worker-wallet',
      builder: (_, __) => const RequireOnboardedWorker(
        child: WalletScreen(role: 'crew'),
      ),
    ),
    GoRoute(
      path: '/onboarding',
      name: 'onboarding',
      builder: (context, st) {
        final extra = st.extra;
        String? prefillName;
        String? prefillUid;
        if (extra is Map<String, dynamic>) {
          prefillName = extra['prefillName'] as String?;
          prefillUid = extra['uid'] as String?;
        }
        return WorkerOnboardingScreen(prefillName: prefillName, prefillUid: prefillUid);
      },
    ),
    GoRoute(path: '/employer/onboarding', name: 'employer-onboarding', builder: (_, __) => const EmployerOnboardingScreen()),
    GoRoute(
      path: '/worker/profile/edit',
      name: 'worker-profile-edit',
      builder: (_, __) => const RequireOnboardedWorker(
        child: WorkerProfileEditScreen(),
      ),
    ),
    GoRoute(path: '/employer', name: 'employer-home', builder: (_, __) => const EmployerHome()),
    GoRoute(path: '/employer/wallet', name: 'employer-wallet', builder: (_, __) => const WalletScreen(role: 'employer')),
    GoRoute(path: '/employer/profile/edit', name: 'employer-profile-edit', builder: (_, __) => const EmployerProfileEditScreen()),
    GoRoute(path: '/employer/vacancy/new', name: 'vacancy-create', builder: (_, __) => const VacancyCreateScreen()),
    GoRoute(
      path: '/employer/vacancy/:id/edit',
      name: 'vacancy-edit',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final Map<String, dynamic>? vacancyData = (state.extra is Map<String, dynamic>) ? (state.extra as Map<String, dynamic>) : null;
        return VacancyEditScreen(vacancyId: id, vacancyData: vacancyData);
      },
    ),
    GoRoute(path: '/profile/edit', name: 'profile-edit', builder: (_, __) => const EditProfileScreen()),
    GoRoute(path: '/settings', name: 'settings', builder: (_, __) => const SettingsScreen()),
  ],
  // DEBUG: helpful log for navigation requests
  redirect: (context, state) {
    // ignore: avoid_print
    print('DEBUG GoRouter requested: ${state.uri}');
    return null;
  },
);
