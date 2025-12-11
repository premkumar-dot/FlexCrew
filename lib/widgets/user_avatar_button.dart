// AppBar avatar + menu (robust) — router-first navigation.
// - Uses FirebaseAuth.currentUser.photoURL first, falls back to one-time Firestore lookup.
// - Avatar + name shown inline in the AppBar; avatar is tappable and opens the menu.
// - Improved visibility and a small fallback menu button when layout is constrained.
// - IMPROVEMENT: Better loading states and error handling for avatars
// - NEW: Account deletion option with consent dialog
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flexcrew/routing/router_globals.dart' as rg;
import 'package:flexcrew/services/navigation_service.dart';
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
/// - IMPROVEMENT: Better loading states and graceful error handling
/// - NEW: Account deletion functionality
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
  String? _resolvedAuthPhoto;
  StreamSubscription<User?>? _authSub;
  String? _hintRole;
  bool _fallbackLoadAttempted = false;
  bool _fallbackLoadFailed = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.currentUser?.reload().then((_) {
      debugPrint('UserAvatarButton: reloaded FirebaseAuth.currentUser');
      _resolveAuthPhotoIfNeeded();
      if (mounted) setState(() {});
    }).catchError((e) {
      debugPrint('UserAvatarButton: reload auth user failed: $e');
    });

    _loadFallback();
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
      if (url.startsWith('gs://')) {
        final ref = FirebaseStorage.instance.refFromURL(url);
        final d = await ref.getDownloadURL();
        debugPrint('UserAvatarButton: resolved gs:// -> $d');
        return d;
      }
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
    if (_fallbackLoadAttempted) {
      debugPrint('UserAvatarButton: _loadFallback skipped (already attempted)');
      return;
    }
    _fallbackLoadAttempted = true;

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

      if (_fallbackPhoto != null && _fallbackPhoto!.startsWith('gs://')) {
        final resolved = await _resolvePhotoUrl(_fallbackPhoto);
        if (resolved != null) {
          debugPrint('UserAvatarButton: resolved fallback gs:// -> $resolved');
          _fallbackPhoto = resolved;
        }
      }
    } catch (e, st) {
      try {
        if (e is FirebaseException && e.code == 'permission-denied') {
          debugPrint('UserAvatarButton: _loadFallback permission-denied: $e');
          _fallbackLoadFailed = true;
        } else {
          debugPrint('UserAvatarButton: _loadFallback error: $e\n$st');
        }
      } catch (_) {
        debugPrint('UserAvatarButton: _loadFallback unexpected error: $e');
      }
    }
    debugPrint('UserAvatarButton: final fallbackPhoto=$_fallbackPhoto fallbackName=$_fallbackName');
    if (mounted) setState(() {});
    try {
      final role = await UserRoleService.instance.getRole();
      if (mounted && role != null) {
        setState(() => _hintRole = role);
      }
    } catch (_) {}
  }

  // IMPROVEMENT: Better avatar widget with loading and error states
  Widget _avatar(BuildContext context, double radius, String displayName, String? photoUrl) {
    final effective = photoUrl ?? '';
    debugPrint('UserAvatarButton: _avatar() photoUrl=$effective');
    
    if (effective.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          effective,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          // IMPROVEMENT: Show loading progress
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: progress.expectedTotalBytes != null
                        ? progress.cumulativeBytesLoaded / (progress.expectedTotalBytes ?? 1)
                        : null,
                  ),
                ),
              ),
            );
          },
          // IMPROVEMENT: Better error fallback with themed colors
          errorBuilder: (ctx, error, stack) {
            debugPrint('UserAvatarButton: Image.network error for $effective -> $error');
            final initials = displayName.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s.characters.first.toUpperCase()).take(2).join();
            return Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.isNotEmpty ? initials : '?',
                  style: TextStyle(
                    fontSize: radius * 0.75,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else {
      final seed = displayName.isNotEmpty ? displayName : 'U';
      final initials = seed.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map((s) => s.characters.first.toUpperCase()).take(2).join();
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            initials.isNotEmpty ? initials : '?',
            style: TextStyle(
              fontSize: radius * 0.75,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
  }

  String _displayName() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    return _titleCase(firebaseUser?.displayName ?? _fallbackName ?? (firebaseUser?.email?.split('@').first ?? 'User'));
  }

  String? _photoUrl() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    final candidate = _resolvedAuthPhoto ?? firebaseUser?.photoURL ?? _fallbackPhoto;
    debugPrint('UserAvatarButton: _photoUrl() -> $candidate');
    return candidate;
  }

  Future<void> _showMenu(BuildContext context, Offset position) async {
    try {
      final items = <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Row(
            children: [
              _avatar(context, 26, _displayName(), _photoUrl()),
              const SizedBox(width: 12),
              Expanded(child: Text(_displayName(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'home', child: Row(children: [Icon(Icons.home, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Home')])),
        PopupMenuItem(value: 'wallet', child: Row(children: [Icon(Icons.account_balance_wallet, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Wallet')])),
        PopupMenuItem(value: 'profile', child: Row(children: [Icon(Icons.edit, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Edit Profile')])),
        PopupMenuItem(value: 'settings', child: Row(children: [Icon(Icons.settings, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Settings')])),
        const PopupMenuDivider(),
        // NEW: Delete Account option
        PopupMenuItem(value: 'delete_account', child: Row(children: [Icon(Icons.delete_forever, size: 20, color: Theme.of(context).colorScheme.error), const SizedBox(width: 12), Text('Delete Account', style: TextStyle(color: Theme.of(context).colorScheme.error))])),
        const PopupMenuDivider(),
        PopupMenuItem(value: 'logout', child: Row(children: [Icon(Icons.logout, size: 20, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), const Text('Logout')])),
      ];

      final selected = await showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
        items: items,
      );
      if (selected != null) _onSelected(selected);
    } catch (e) {
      debugPrint('UserAvatarButton: showMenu error: $e');
    }
  }

  Future<void> _deleteAccount() async {
    // Step 1: Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text(
          'This will permanently delete your account and all associated data including:\n\n'
          '• Profile information\n'
          '• Applications\n'
          '• Posted vacancies (if employer)\n'
          '• Uploaded documents\n\n'
          'This action cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(c).colorScheme.error),
            child: const Text('Delete Forever'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Step 2: Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Expanded(child: Text('Deleting your account...')),
          ],
        ),
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final uid = user.uid;

      // Step 3: Delete Firestore documents
      final batch = FirebaseFirestore.instance.batch();

      // Delete user collections
      batch.delete(FirebaseFirestore.instance.collection('users').doc(uid));
      batch.delete(FirebaseFirestore.instance.collection('workers').doc(uid));
      batch.delete(FirebaseFirestore.instance.collection('employers').doc(uid));
      batch.delete(FirebaseFirestore.instance.collection('profiles').doc(uid));

      // Delete applications where user is the worker
      final applicationsQuery = await FirebaseFirestore.instance
          .collection('applications')
          .where('workerId', isEqualTo: uid)
          .get();
      for (final doc in applicationsQuery.docs) {
        batch.delete(doc.reference);
      }

      // Delete vacancies where user is the employer
      final vacanciesQuery = await FirebaseFirestore.instance
          .collection('vacancies')
          .where('employerId', isEqualTo: uid)
          .get();
      for (final doc in vacanciesQuery.docs) {
        batch.delete(doc.reference);
      }

      // Commit Firestore deletions
      await batch.commit();

      // Step 4: Delete Storage files (avatar, documents)
      try {
        final storageRef = FirebaseStorage.instance.ref();
        
        // Delete avatars
        final avatarRef = storageRef.child('avatars').child(uid);
        final avatarList = await avatarRef.listAll();
        for (final item in avatarList.items) {
          await item.delete();
        }

        // Delete worker documents
        final docsRef = storageRef.child('workerDocs').child(uid);
        final docsList = await docsRef.listAll();
        for (final item in docsList.items) {
          await item.delete();
        }

        // Delete profiles
        final profilesRef = storageRef.child('profiles').child(uid);
        final profilesList = await profilesRef.listAll();
        for (final item in profilesList.items) {
          await item.delete();
        }
      } catch (storageError) {
        debugPrint('Storage deletion error (non-fatal): $storageError');
        // Continue even if storage deletion fails
      }

      // Step 5: Delete Firebase Auth user
      await user.delete();

      // Step 6: Close progress dialog and navigate to login
      if (!mounted) return;
      Navigator.of(context).pop(); // Close progress dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted successfully')),
      );

      // Navigate to login
      try {
        rg.appRouter.go('/auth-external');
      } catch (_) {
        try {
          NavigationService.instance.go('/auth-external');
        } catch (_) {
          Navigator.of(context).pushNamedAndRemoveUntil('/auth-external', (r) => false);
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close progress dialog
      
      String errorMsg = 'Failed to delete account';
      if (e.code == 'requires-recent-login') {
        errorMsg = 'Please sign out and sign in again before deleting your account';
      } else {
        errorMsg = 'Failed to delete account: ${e.message}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Theme.of(context).colorScheme.error),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close progress dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete account: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _onSelected(String value) async {
    try {
      debugPrint('AvatarMenu: selected=$value');
      switch (value) {
        case 'home':
          {
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
        case 'delete_account':
          await _deleteAccount();
          break;
        case 'logout':
          await FirebaseAuth.instance.signOut();
          try {
            rg.appRouter.go('/auth-external');
          } catch (_) {
            try {
              NavigationService.instance.go('/auth-external');
            } catch (_) {
              Navigator.of(context).pushNamedAndRemoveUntil('/auth-external', (r) => false);
            }
          }
          break;
      }
    } catch (e) {
      print('Avatar menu navigation error: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Navigation Failed: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName();
    final photo = _photoUrl();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: LayoutBuilder(builder: (context, constraints) {
        final availableHeight = (constraints.maxHeight.isFinite && constraints.maxHeight > 0) ? constraints.maxHeight : kToolbarHeight;
        final reservedForName = (displayName.isNotEmpty) ? 16.0 + 4.0 : 0.0;
        final avatarDiameter = ((availableHeight - reservedForName)).clamp(32.0, 44.0);
        final avatarRadius = avatarDiameter / 2.0;

        final screen = MediaQuery.of(context).size.width;
        final parentMaxWidth = (constraints.maxWidth.isFinite && constraints.maxWidth > 0) ? constraints.maxWidth : (screen * 0.32);
        final maxNameWidth = parentMaxWidth.clamp(80.0, 320.0);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTapDown: (details) async {
                await _showMenu(context, details.globalPosition);
              },
              child: _avatar(context, avatarRadius, displayName, photo),
            ),

            // Provide a compact name label (use onSurface for legibility on different appbar backgrounds)
            if (displayName.isNotEmpty) ...[
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxNameWidth, minWidth: 0),
                child: Tooltip(
                  message: displayName,
                  child: Text(
                    displayName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                  ),
                ),
              ),
            ],
          ],
        );
      }),
    );
  }
}
