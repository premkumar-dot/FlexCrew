// AppBar avatar + menu (stable PopupMenuButton) — router-first navigation.
// - Uses FirebaseAuth.currentUser.photoURL first, falls back to one-time Firestore lookup.
// - Avatar + name shown inline in the AppBar; avatar is tappable and opens the menu.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flexcrew/features/auth/sign_in_screen.dart';
import 'package:flexcrew/routing/router_globals.dart' as rg;
import 'package:flexcrew/services/user_role_service.dart';

String _titleCase(String? input) {
  if (input == null) return '';
  final trimmed = input.trim();
  if (trimmed.isEmpty) return '';
  return trimmed
      .split(RegExp(r'\s+'))
      .map((part) {
        if (part.isEmpty) return '';
        if (part.length == 1) return part[0].toUpperCase();
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .where((p) => p.isNotEmpty)
      .join(' ');
}

String? _resolveNameFromDoc(Map<String, dynamic>? m) {
  if (m == null) return null;
  final fullKeys = [
    'fullName',
    'fullname',
    'full_name',
    'name',
    'displayName',
    'display_name',
    'companyName'
  ];
  for (final k in fullKeys) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  final firstCandidates = ['firstName', 'firstname', 'first_name', 'first'];
  final lastCandidates = ['lastName', 'lastname', 'last_name', 'last'];
  String? first;
  String? last;
  for (final k in firstCandidates) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) {
      first = v.trim();
      break;
    }
  }
  for (final k in lastCandidates) {
    final v = m[k];
    if (v is String && v.trim().isNotEmpty) {
      last = v.trim();
      break;
    }
  }
  if ((first ?? '').isNotEmpty && (last ?? '').isNotEmpty) {
    return '${first!} ${last!}'.trim();
  }
  if ((first ?? '').isNotEmpty) return first;
  if ((last ?? '').isNotEmpty) return last;
  return null;
}

class UserAvatarButton extends StatefulWidget {
  const UserAvatarButton({super.key, this.basePath});
  final String? basePath;

  @override
  State<UserAvatarButton> createState() => _UserAvatarButtonState();
}

class _UserAvatarButtonState extends State<UserAvatarButton> {
  String? _fallbackPhoto;
  String? _fallbackName;
  String? _fallbackRole;
  StreamSubscription<User?>? _authSub;
  // small local hint used for building the menu quickly; authoritative role should come from UserRoleService
  String? _hintRole;

  @override
  void initState() {
    super.initState();
    _loadFallback();
    // Rebuild when Firebase Auth user changes so photoURL/displayName updates immediately
    _authSub = FirebaseAuth.instance.userChanges().listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _loadFallback() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final usersDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final usersData = usersDoc.data();
      if (usersData != null) {
        _fallbackName ??= _resolveNameFromDoc(usersData);
        _fallbackPhoto ??= (usersData['photoUrl'] ?? usersData['avatarUrl'] ?? usersData['photo'] ?? usersData['imageUrl']) as String?;
        _fallbackRole ??= (usersData['role'] as String?)?.trim();
      }

      if ((_fallbackPhoto == null || _fallbackName == null)) {
        final emplDoc = await FirebaseFirestore.instance.collection('employers').doc(uid).get();
        final eData = emplDoc.data();
        if (eData != null) {
          _fallbackName ??= _resolveNameFromDoc(eData);
          _fallbackPhoto ??= (eData['logoUrl'] ?? eData['photoUrl'] ?? eData['imageUrl'] ?? eData['avatarUrl']) as String?;
        }
      }

      if ((_fallbackPhoto == null || _fallbackName == null)) {
        final profilesDoc = await FirebaseFirestore.instance.collection('profiles').doc(uid).get();
        final pData = profilesDoc.data();
        if (pData != null) {
          _fallbackName ??= _resolveNameFromDoc(pData);
          _fallbackPhoto ??= (pData['photoUrl'] ?? pData['avatarUrl'] ?? pData['imageUrl']) as String?;
        }
      }
    } catch (_) {
      // ignore network errors
    }
    if (mounted) setState(() {});
    // also pre-warm cached role from the role service if not set
    try {
      final role = await UserRoleService.instance.getRole();
      if (mounted && role != null) {
        setState(() => _hintRole = role);
      }
    } catch (_) {}
  }

  Widget _avatar(double radius, String displayName, String? photoUrl) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photoUrl), backgroundColor: Colors.transparent);
    } else {
      final seed = displayName.isNotEmpty ? displayName : 'U';
      final initials = seed
          .trim()
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((s) => s.characters.first.toUpperCase())
          .take(2)
          .join();
      return CircleAvatar(radius: radius, child: Text(initials, style: TextStyle(fontSize: radius * 0.75)));
    }
  }

  String _displayName() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    return _titleCase(firebaseUser?.displayName ?? _fallbackName ?? (firebaseUser?.email?.split('@').first ?? 'User'));
  }

  String? _photoUrl() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    return firebaseUser?.photoURL ?? _fallbackPhoto;
  }

  void _onSelected(String value) async {
    try {
      // telemetry: selected action
      debugPrint('AvatarMenu: selected=$value');
      switch (value) {
        case 'home':
          {
            // Resolve role via service (cached + safe fetch)
            String role = _hintRole ?? '';
            try {
              final svcRole = await UserRoleService.instance.getRole(refresh: false);
              if (svcRole != null && svcRole.trim().isNotEmpty) role = svcRole.trim();
            } catch (_) {}

            debugPrint('AvatarMenu: routing home for role="$role"');
            if (role.toLowerCase() == 'employer') {
              try {
                rg.appRouter.go('/employer');
              } catch (_) {
                Navigator.of(context).pushNamedAndRemoveUntil('/employer', (r) => false);
              }
            } else {
              try {
                rg.appRouter.go('/worker');
              } catch (_) {
                Navigator.of(context).pushNamedAndRemoveUntil('/worker', (r) => false);
              }
            }
          }
          break;
        case 'wallet':
          {
            String role = _hintRole ?? '';
            try {
              final svcRole = await UserRoleService.instance.getRole(refresh: false);
              if (svcRole != null && svcRole.trim().isNotEmpty) role = svcRole.trim();
            } catch (_) {}
            debugPrint('AvatarMenu: routing wallet for role="$role"');
            if (role.toLowerCase() == 'employer') {
              try {
                rg.appRouter.go('/employer/wallet');
              } catch (_) {
                Navigator.of(context).pushNamed('/employer/wallet');
              }
            } else {
              try {
                rg.appRouter.go('/worker/wallet');
              } catch (_) {
                Navigator.of(context).pushNamed('/worker/wallet');
              }
            }
          }
          break;
        case 'post_vacancy':
          try {
            debugPrint('AvatarMenu: post_vacancy tapped');
            rg.appRouter.pushNamed('vacancy-create');
          } catch (_) {
            Navigator.of(context).pushNamed('/employer/vacancy/new');
          }
          break;
        case 'profile':
          // Resolve persisted role and navigate to the appropriate profile edit
          try {
            final uid = FirebaseAuth.instance.currentUser?.uid;
            String role = '';
            if (uid != null) {
              try {
                final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
                role = (doc.data()?['role'] as String?) ?? '';
              } catch (_) {}
            }
            if (role.trim().toLowerCase() == 'employer') {
              try {
                rg.appRouter.go('/employer/profile/edit');
              } catch (_) {
                Navigator.of(context).pushNamed('/employer/profile/edit');
              }
            } else {
              try {
                rg.appRouter.go('/worker/profile/edit');
              } catch (_) {
                Navigator.of(context).pushNamed('/worker/profile/edit');
              }
            }
          } catch (e) {
            rethrow;
          }
          break;
        case 'settings':
          try {
            rg.appRouter.go('/settings');
          } catch (_) {
            Navigator.of(context).pushNamed('/settings');
          }
          break;
        case 'logout':
          await FirebaseAuth.instance.signOut();
          try {
            rg.appRouter.go('/login');
          } catch (_) {
            Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const SignInScreen()), (r) => false);
          }
          break;
      }
    } catch (e) {
      // ignore: avoid_print
      print('Avatar menu navigation error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigation Failed: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName();
    final photo = _photoUrl();

    // Show avatar + name inline so AppBar displays both; avatar is the tappable child.
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<String>(
            tooltip: 'Account',
            color: Theme.of(context).colorScheme.surface,
            onSelected: _onSelected,
            itemBuilder: (c) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Row(
                  children: [
                    _avatar(26, displayName, photo),
                    const SizedBox(width: 12),
                    Expanded(child: Text(displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'home', child: Row(children: [Icon(Icons.home, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Home')])),
              PopupMenuItem(value: 'wallet', child: Row(children: [Icon(Icons.account_balance_wallet, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Wallet')])),
              PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Edit Profile')])),
              PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Settings')])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Logout')])),
            ],
            // Tappable avatar
            child: Material(type: MaterialType.transparency, child: _avatar(20, displayName, photo)),
          ),
          const SizedBox(width: 8),
          // Name shown to the right (non-tappable)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
