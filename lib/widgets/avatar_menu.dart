import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

/// Reusable AvatarMenu widget that shows user's avatar and menu items.
class AvatarMenu extends StatelessWidget {
  final User user;
  const AvatarMenu({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final photo = user.photoURL;
    final iconColor = Theme.of(context).colorScheme.primary;
    final labelStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(color: iconColor);

    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<int>(
            tooltip: 'Account',
            onSelected: (value) async {
              if (value == 1) {
                context.go('/profile/edit');
              } else if (value == 2) {
                context.go('/settings');
              } else if (value == 3) {
                await FirebaseAuth.instance.signOut();
                context.go('/login');
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 1,
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 20, color: iconColor),
                    const SizedBox(width: 12),
                    Text('Edit profile', style: labelStyle),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 2,
                child: Row(
                  children: [
                    Icon(Icons.settings, size: 20, color: iconColor),
                    const SizedBox(width: 12),
                    Text('Settings', style: labelStyle),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 3,
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 20, color: iconColor),
                    const SizedBox(width: 12),
                    Text('Sign out', style: labelStyle),
                  ],
                ),
              ),
            ],
            child: CircleAvatar(
              radius: 18,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null ? const Icon(Icons.person) : null,
            ),
          ),
        ],
      ),
    );
  }
}

/// Auth-aware overlay that listens to auth state and inserts an OverlayEntry
/// into the app's root overlay. This ensures PopupMenuButton finds an Overlay.
class AuthAwareAvatarOverlay extends StatefulWidget {
  const AuthAwareAvatarOverlay({super.key});

  @override
  State<AuthAwareAvatarOverlay> createState() => _AuthAwareAvatarOverlayState();
}

class _AuthAwareAvatarOverlayState extends State<AuthAwareAvatarOverlay> {
  StreamSubscription<User?>? _sub;
  OverlayEntry? _entry;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _sub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  void _onAuthChanged(User? user) {
    // no-op if same user
    if (user?.uid == _currentUser?.uid) return;
    _currentUser = user;

    // remove any existing entry
    _removeEntry();

    if (user == null) return;

    // Try to get the app's root overlay (recommended)
    OverlayState? overlay;
    try {
      overlay = Navigator.of(context, rootNavigator: true).overlay;
    } catch (_) {
      overlay = null;
    }

    if (overlay != null) {
      _insertEntry(overlay, user);
    } else {
      // Overlay not available yet (context may be too early). Try after frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final afterOverlay = Navigator.of(context, rootNavigator: true).overlay;
          if (afterOverlay != null) _insertEntry(afterOverlay, user);
        } catch (_) {
          // ignore - overlay still not available
        }
      });
    }
  }

  void _insertEntry(OverlayState overlay, User user) {
    _entry = OverlayEntry(builder: (ctx) {
      return Positioned(
        top: 12,
        right: 12,
        child: SafeArea(child: AvatarMenu(user: user)),
      );
    });
    try {
      overlay.insert(_entry!);
    } catch (_) {
      // if insert fails, ensure entry null to avoid leaks
      _entry = null;
    }
  }

  void _removeEntry() {
    if (_entry != null) {
      try {
        _entry!.remove();
      } catch (_) {}
      _entry = null;
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _removeEntry();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This widget itself renders nothing — overlay entry manages UI.
    return const SizedBox.shrink();
  }
}
