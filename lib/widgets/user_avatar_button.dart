// AppBar avatar + menu (stable PopupMenuButton) — router-first navigation.
// - Uses FirebaseAuth.currentUser.photoURL first, falls back to one-time Firestore lookup.
// - Avatar + name shown inline in the AppBar; avatar is tappable and opens the menu.
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

/// UserAvatarButton
/// - Small reusable avatar button that shows a popup menu.
/// - Uses the global `appRouter` for navigation to avoid context-based GoRouter lookups.
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
  String? _resolvedAuthPhoto; // resolved auth photo (https) if needed
  StreamSubscription<User?>? _authSub;
  // small local hint used for building the menu quickly; authoritative role should come from UserRoleService
  String? _hintRole;

  @override
  void initState() {
    super.initState();
    // Try to refresh auth user first (provider may set photoURL asynchronously)
    FirebaseAuth.instance.currentUser?.reload().then((_) {
      debugPrint('UserAvatarButton: reloaded FirebaseAuth.currentUser');
      _resolveAuthPhotoIfNeeded();
      if (mounted) setState(() {});
    }).catchError((e) {
      debugPrint('UserAvatarButton: reload auth user failed: $e');
    });

    _loadFallback();
    // Rebuild when Firebase Auth user changes so photoURL/displayName updates immediately
    _authSub = FirebaseAuth.instance.userChanges().listen((_) {
      if (mounted) setState(() {});
      _resolveAuthPhotoIfNeeded();
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<String?> _resolvePhotoUrl(String? url) async {
    if (url == null) return null;
    try {
      // gs:// URLs need conversion to HTTPS via Firebase Storage
      if (url.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final d = await ref.getDownloadURL();
        debugPrint('UserAvatarButton: resolved gs:// -> $d');
        return d;
      }
      // If already https/http or data URI, return as-is
      return url;
    } catch (e) {
      debugPrint('UserAvatarButton: failed to resolve photo URL $url -> $e');
      return null;
    }
  }

  Future<void> _resolveAuthPhotoIfNeeded() async {
    final authUrl = FirebaseAuth.instance.currentUser?.photoURL;
    if (authUrl == null) {
      debugPrint('UserAvatarButton: no auth photoURL available');
      return;
    }
    final resolved = await _resolvePhotoUrl(authUrl);
    if (mounted) setState(() => _resolvedAuthPhoto = resolved);
    debugPrint('UserAvatarButton: auth photo resolved to=$_resolvedAuthPhoto');
  }

  Future<void> _loadFallback() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    debugPrint('UserAvatarButton: _loadFallback for uid=$uid');
    if (uid == null) return;
    try {
      final usersDocRef = FirebaseFirestore.instance.collection('users').doc(uid);
      final usersDoc = await usersDocRef.get();
      final usersData = usersDoc.data();
      debugPrint('UserAvatarButton: users doc for $uid -> ${usersData ?? "<null>"}');

      if (usersData != null) {
        _fallbackName ??= _resolveNameFromDoc(usersData);
        _fallbackPhoto ??= (usersData['photoUrl'] ?? usersData['avatarUrl'] ?? usersData['photo'] ?? usersData['imageUrl']) as String?;
        _fallbackRole ??= (usersData['role'] as String?)?.trim();
        debugPrint('UserAvatarButton: usersData fallbackName=$_fallbackName fallbackPhoto=$_fallbackPhoto fallbackRole=$_fallbackRole');
      }

      // Also check employers collection (if user is an employer)
      if ((_fallbackPhoto == null || _fallbackName == null)) {
        final emplDoc = await FirebaseFirestore.instance.collection('employers').doc(uid).get();
        final eData = emplDoc.data();
        debugPrint('UserAvatarButton: employers doc for $uid -> ${eData ?? "<null>"}');
        if (eData != null) {
          _fallbackName ??= _resolveNameFromDoc(eData);
          _fallbackPhoto ??= (eData['logoUrl'] ?? eData['photoUrl'] ?? eData['imageUrl'] ?? eData['avatarUrl']) as String?;
          debugPrint('UserAvatarButton: employers fallbackName=$_fallbackName fallbackPhoto=$_fallbackPhoto');
        }
      }

      // Also check profiles collection
      if ((_fallbackPhoto == null || _fallbackName == null)) {
        final profilesDoc = await FirebaseFirestore.instance.collection('profiles').doc(uid).get();
        final pData = profilesDoc.data();
        debugPrint('UserAvatarButton: profiles doc for $uid -> ${pData ?? "<null>"}');
        if (pData != null) {
          _fallbackName ??= _resolveNameFromDoc(pData);
          _fallbackPhoto ??= (pData['photoUrl'] ?? pData['avatarUrl'] ?? pData['imageUrl']) as String?;
          debugPrint('UserAvatarButton: profiles fallbackName=$_fallbackName fallbackPhoto=$_fallbackPhoto');
        }
      }

      // NEW: Also check workers collection (some flows write worker profile/avatar here)
      if ((_fallbackPhoto == null || _fallbackName == null)) {
        final workerDoc = await FirebaseFirestore.instance.collection('workers').doc(uid).get();
        final wData = workerDoc.data();
        debugPrint('UserAvatarButton: workers doc for $uid -> ${wData ?? "<null>"}');
        if (wData != null) {
          _fallbackName ??= _resolveNameFromDoc(wData);
          _fallbackPhoto ??= (wData['photoUrl'] ?? wData['avatarUrl'] ?? wData['imageUrl'] ?? wData['photo']) as String?;
          debugPrint('UserAvatarButton: workers fallbackName=$_fallbackName fallbackPhoto=$_fallbackPhoto');
        }
      }

      // If fallback photo uses gs:// convert it to https
      if (_fallbackPhoto != null && _fallbackPhoto!.startsWith('gs://')) {
        final resolved = await _resolvePhotoUrl(_fallbackPhoto);
        if (resolved != null) {
          debugPrint('UserAvatarButton: resolved fallback gs:// -> $resolved');
          _fallbackPhoto = resolved;
        }
      }
    } catch (e, st) {
      debugPrint('UserAvatarButton: _loadFallback error: $e\n$st');
    }
    debugPrint('UserAvatarButton: final fallbackPhoto=$_fallbackPhoto fallbackName=$_fallbackName');
    if (mounted) setState(() {});
    // also pre-warm cached role from the role service if not set
    try {
      final role = await UserRoleService.instance.getRole();
      if (mounted && role != null) {
        setState(() => _hintRole = role);
      }
    } catch (_) {}
  }

  Widget _avatar(BuildContext context, double radius, String displayName, String? photoUrl) {
    final effective = photoUrl ?? '';
    debugPrint('UserAvatarButton: _avatar() photoUrl=$effective');
    if (effective.isNotEmpty) {
      // Use Image.network with errorBuilder to catch load/CORS/404 issues and log them
      return ClipOval(
        child: Image.network(
          effective,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return SizedBox(width: radius * 2, height: radius * 2, child: Center(child: SizedBox(width: radius * 0.8, height: radius * 0.8, child: const CircularProgressIndicator(strokeWidth: 2))));
          },
          errorBuilder: (ctx, error, stack) {
            debugPrint('UserAvatarButton: Image.network error for $effective -> $error');
            final initials = displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s.characters.first.toUpperCase()).take(2).join();
            return Container(
              width: radius * 2,
              height: radius * 2,
              color: Theme.of(context).colorScheme.surface,
              child: Center(child: Text(initials, style: TextStyle(fontSize: radius * 0.75))),
            );
          },
        ),
      );
    } else {
      final seed = displayName.isNotEmpty ? displayName : 'U';
      final initials = seed.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s.characters.first.toUpperCase()).take(2).join();
      return CircleAvatar(radius: radius, child: Text(initials, style: TextStyle(fontSize: radius * 0.75)));
    }
  }

  String _displayName() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    return _titleCase(firebaseUser?.displayName ?? _fallbackName ?? (firebaseUser?.email?.split('@').first ?? 'User'));
  }

  String? _photoUrl() {
    // Prefer resolved auth photo, then auth photo, then fallback (which we already resolved if gs://)
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final candidate = _resolvedAuthPhoto ?? firebaseUser?.photoURL ?? _fallbackPhoto;
    debugPrint('UserAvatarButton: _photoUrl() -> $candidate');
    return candidate;
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
                    _avatar(context, 26, displayName, photo),
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
            child: Material(type: MaterialType.transparency, child: _avatar(context, 20, displayName, photo)),
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
