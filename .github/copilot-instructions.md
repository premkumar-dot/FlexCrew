## Copilot instructions for the FlexCrew mobile app

Purpose: help an AI coding agent be productive quickly in this Flutter repo by pointing to the
project's architecture, conventions, integration points, and concrete examples to use as anchors.

- Project type: Flutter mobile app (Android/iOS), single Flutter package at repo root.
- State management: `flutter_riverpod` (declared in `pubspec.yaml`).
- Routing: `go_router` with a global `appRouter` defined in `lib/routing/app_router.dart`.
- Backend: Firebase (core, auth, firestore, storage, messaging). Firebase options are generated
  into `lib/firebase_options.dart` by the FlutterFire CLI.

Big picture / architecture (what to read first)

- Entry point: `lib/main.dart` — initializes Firebase and starts `MaterialApp.router` with
  `appRouter`.
- Routing + auth guard: `lib/routing/app_router.dart` — routes (e.g. `/login`, `/create-account`,
  `/worker`, `/employer`) and a redirect that checks `FirebaseAuth.instance.currentUser`.
  Use this as the canonical example of route-based auth checks.
- Feature layout: `lib/features/*` — feature folders (auth, home, profile, etc.) contain UI and
  feature-specific screens. Follow that pattern when adding screens or features.
- Shared services: `lib/services/` and `lib/core/services/` — singleton-style service wrappers
  (example: `lib/services/storage_service.dart` with `StorageService.instance`).

Concrete integration examples (copyable patterns)

- Auth-based redirect: `lib/routing/app_router.dart` uses `FirebaseAuth.instance.currentUser`
  to redirect unauthenticated users to `/login` and to route authenticated users to `/worker`.
- Storage uploads: `lib/services/storage_service.dart` -> `uploadAvatar(...)` uploads bytes to
  `avatars/{uid}/avatar.jpg` and returns a download URL (uses `SettableMetadata(contentType: ...)`).
- Firebase config: `lib/firebase_options.dart` is generated. If you need to change Firebase
  projects or platforms, re-run the FlutterFire CLI rather than editing that file manually.

Build, run, and test workflows (what agents should run / expect)

- Install deps: `flutter pub get` (standard Flutter workspace top-level).
- Run app (dev): `flutter run` or use the device chooser in the editor. `main.dart` is
  entrypoint; the app uses `MaterialApp.router` and `appRouter` for navigation.
- Build release APK: `flutter build apk` (Android) or `flutter build ipa` for iOS (macOS only).
- Tests: `flutter test` runs unit/widget tests (there is `test/widget_test.dart`).

Project-specific conventions & patterns

- Feature-first layout: add new UI/screens under `lib/features/<feature>/` following the
  existing naming conventions (e.g. `worker_home.dart`, `login_screen.dart`).
- Singletons for platform services: use `.instance` singletons (see `StorageService.instance`).
- Router-first navigation: prefer named routes and `GoRouter` constructs from
  `lib/routing/app_router.dart` rather than ad-hoc `Navigator.push` calls.
- Assets: declared in `pubspec.yaml` under `assets/branding/` and `assets/icons/` — reuse
  existing SVGs and PNGs for consistent branding.

Integration points & external dependencies

- Firebase (auth, firestore, storage, messaging). Native config files exist (Android's
  `android/app/google-services.json`, iOS `Runner/Info.plist`) — be careful changing Firebase
  configuration; use FlutterFire CLI and verify `lib/firebase_options.dart`.
- Google Sign-In and SharedPreferences are present (`google_sign_in`, `shared_preferences`) —
  check `lib/features/auth` for onboarding/cache implementations.
- Messaging: `firebase_messaging` is included; see feature code for registration and handlers.

What NOT to change without caution

- `lib/firebase_options.dart` (generated) — re-generate via FlutterFire CLI if needed.
- Native platform files under `android/` and `ios/` unless you understand Gradle/Kotlin DSL
  or Xcode bundle settings.

Where to look for more context

- Routing/auth logic: `lib/routing/app_router.dart` (example redirect based on FirebaseAuth).
- App entry & theme: `lib/main.dart`, `lib/theme/app_theme.dart`.
- Storage upload example: `lib/services/storage_service.dart`.
- Feature examples: `lib/features/auth/*`, `lib/features/home/*`, `lib/features/profile/*`.

Quick checklist for small edits by an AI agent

1. Run `flutter pub get` locally to ensure dependencies resolve.
2. Run a single test (`flutter test test/widget_test.dart`) after code changes to catch obvious
   regressions.
3. If touching Firebase/platform config: update via FlutterFire CLI and verify `lib/firebase_options.dart`.
4. Follow existing feature folder and naming conventions for new screens/services.

If any of these areas are unclear or you'd like more detail (CI, lints, or provider locations),
tell me which part to expand and I'll update this file.
