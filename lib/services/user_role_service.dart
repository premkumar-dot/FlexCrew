import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Tiny cached user-role helper used across the app.
/// - caches value for [ttl] and will refresh from Firestore when requested.
class UserRoleService {
  UserRoleService._();
  static final UserRoleService instance = UserRoleService._();

  String? _cachedRole;
  DateTime? _lastFetched;
  Duration ttl = const Duration(seconds: 30);

  Future<String?> getRole({bool refresh = false}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    if (!refresh && _cachedRole != null && _lastFetched != null && DateTime.now().difference(_lastFetched!) < ttl) {
      return _cachedRole;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final role = (doc.data()?['role'] as String?)?.trim();
      _cachedRole = role;
      _lastFetched = DateTime.now();
      return _cachedRole;
    } catch (_) {
      // silent fallback to cached value if network/read fails
      return _cachedRole;
    }
  }

  /// Force clear cache (useful for sign out / role change tests)
  void clearCache() {
    _cachedRole = null;
    _lastFetched = null;
  }
}
