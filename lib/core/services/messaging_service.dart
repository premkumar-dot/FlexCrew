import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Push notifications helper.
/// On web, this becomes a no-op so you can run the app in Chrome/Edge without setup.
class MessagingService {
  static final FirebaseMessaging _m = FirebaseMessaging.instance;

  static Future<void> init() async {
    // Skip on web to avoid service worker setup for now.
    if (kIsWeb) {
      debugPrint('[MessagingService] Web detected — skipping FCM init.');
      return;
    }

    // Request permissions (iOS)
    await _m.requestPermission(alert: true, badge: true, sound: true);

    // Get and save initial token
    final token = await _m.getToken();
    await _saveToken(token);

    // Listen for token refresh
    _m.onTokenRefresh.listen(_saveToken);

    // Optional: log foreground messages
    FirebaseMessaging.onMessage.listen((msg) {
      debugPrint('[FCM] ${msg.notification?.title} ${msg.data}');
    });

    // Optional: handle tapping a notification to open the app
    FirebaseMessaging.onMessageOpenedApp.listen((msg) {
      debugPrint('[FCM] onMessageOpenedApp data=${msg.data}');
      // You can navigate based on msg.data here if desired.
    });
  }

  static Future<void> _saveToken(String? token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token == null) return;

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('fcmTokens')
        .doc(token);

    await ref.set({
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

