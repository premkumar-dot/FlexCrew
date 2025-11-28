import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' as f;

class ApplicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Avoid mixing Dart timeout futures with JS-backed Firestore promises on web.
  // On web we return the original future to prevent JS/Dart boxing errors.
  Future<T> _withPlainTimeout<T>(Future<T> future, Duration timeout, String message) {
    // On web we avoid wrapping Firestore promises to prevent JS/Dart boxing errors.
    if (f.kIsWeb) {
      return future;
    }

    // Use a plain Exception for the timeout so the error crossing boundaries
    // is always a Dart Exception with a simple message (avoids boxing issues).
    final timeoutFuture = Future<T>.delayed(timeout, () => throw Exception(message));
    return Future.any([future, timeoutFuture]);
  }

  // Helper to safely extract a string note/message from the optional extra map.
  String _noteFromExtra(Map<String, dynamic>? extra) {
    if (extra == null) return '';
    final v = extra['note'] ?? extra['message'];
    if (v is String) return v;
    return '';
  }

  /// Create an application (Express Interest).
  /// - Allows re-apply by updating an existing withdrawn/deleted/cancelled doc.
  /// - Accepts nullable employerId to match callers.
  /// - Appends a timeline entry for creation / re-apply.
  Future<void> createApplication({
    required String vacancyId,
    required String workerId,
    String? employerId,
    String? vacancyTitle,
    Map<String, dynamic>? extra,
  }) async {
    // Ensure currentUser is fresh (web sometimes yields stale null).
    User? user = _auth.currentUser;
    if (user == null) {
      try {
        await _auth.currentUser?.reload();
      } catch (e) {
        // ignore reload error, we'll check currentUser again
      }
      user = _auth.currentUser;
    }

    if (user == null || user.uid != workerId) {
      f.debugPrint('ApplicationService.createApplication: auth mismatch user=${user?.uid} expected=$workerId');
      throw Exception('User not authenticated');
    }

    try {
      final dup = await _db
          .collection('applications')
          .where('vacancyId', isEqualTo: vacancyId)
          .where('workerId', isEqualTo: workerId)
          .limit(1)
          .get();

      if (dup.docs.isNotEmpty) {
        final existing = dup.docs.first;
        final rawStatus = existing.data()['status'];
        final existingStatus = (rawStatus is String ? rawStatus : '').toLowerCase().trim();

        f.debugPrint('createApplication: found existing application doc=${existing.id} status="$existingStatus"');

        const reapplyable = {'withdrawn', 'deleted', 'cancelled', 'canceled', 'rejected'};

        if (reapplyable.contains(existingStatus)) {
          final docRef = _db.collection('applications').doc(existing.id);

          // Use concrete Timestamp for timeline entries (serverTimestamp can't be nested in arrayUnion)
          final timelineTs = Timestamp.fromDate(DateTime.now().toUtc());
          final serverNow = FieldValue.serverTimestamp();

          // Build timeline entry using helper
          final String note = _noteFromExtra(extra);
          final Map<String, dynamic> timelineEntry = <String, dynamic>{
            'status': 'sent',
            'label': 'Application submitted',
            'ts': timelineTs,
            'by': workerId,
            'note': note,
          };

          final updateData = <String, dynamic>{
            'vacancyId': vacancyId,
            'vacancyTitle': vacancyTitle ?? (existing.data()['vacancyTitle'] ?? ''),
            'employerId': employerId ?? existing.data()['employerId'],
            'workerId': workerId,
            'workerEmail': user.email ?? existing.data()['workerEmail'] ?? '',
            'status': 'sent',
            'updatedAt': serverNow,
            'reappliedAt': serverNow,
            // append timeline entry (use concrete timestamp inside)
            'timeline': FieldValue.arrayUnion([timelineEntry]),
          };
          if (extra != null) updateData.addAll(extra);

          await docRef.update(updateData);
          f.debugPrint('createApplication: reused doc=${existing.id} for re-apply');
          return;
        }

        throw Exception('You have already applied for this vacancy (status: ${existingStatus.isEmpty ? 'unknown' : existingStatus})');
      }
    } catch (err, st) {
      f.debugPrint('ApplicationService.createApplication duplicate-check error: $err\n$st');
      throw Exception('Failed to verify existing applications');
    }

    // For initial creation: use concrete timestamp for timeline entries, serverTimestamp for createdAt/updatedAt
    final timelineTs = Timestamp.fromDate(DateTime.now().toUtc());
    final serverNow = FieldValue.serverTimestamp();

    // Compose initial timeline entry, include optional note from extra if present
    final String initialNote = _noteFromExtra(extra);
    final Map<String, dynamic> initialTimelineEntry = <String, dynamic>{
      'status': 'sent',
      'label': 'Application submitted',
      'ts': timelineTs,
      'by': workerId,
      'note': initialNote,
    };

    final docData = <String, dynamic>{
      'vacancyId': vacancyId,
      'vacancyTitle': vacancyTitle ?? '',
      'employerId': employerId,
      'workerId': workerId,
      'workerEmail': user.email ?? '',
      'status': 'sent',
      'createdAt': serverNow,
      'updatedAt': serverNow,
      // initial timeline array (use concrete timestamp)
      'timeline': [initialTimelineEntry],
    };

    if (extra != null) docData.addAll(extra);

    try {
      f.debugPrint('ApplicationService.createApplication: writing new application for vacancy=$vacancyId worker=$workerId');
      await _withPlainTimeout(
        _db.collection('applications').add(docData),
        const Duration(seconds: 12),
        'Network timeout — please try again',
      );
      f.debugPrint('ApplicationService.createApplication: write completed for vacancy=$vacancyId');
    } catch (err, st) {
      f.debugPrint('ApplicationService.createApplication write error: $err\n$st');

      if (err is TimeoutException || err.toString().contains('TimeoutException')) {
        throw Exception('Network timeout — please try again');
      }

      // Re-throw with the original message to surface to callers
      throw Exception(err?.toString() ?? 'Failed to create application');
    }
  }

  Future<void> expressInterest({
    required String vacancyId,
    String? employerId,
    String? vacancyTitle,
    Map<String, dynamic>? extra,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      // attempt reload once
      try {
        await _auth.currentUser?.reload();
      } catch (_) {}
    }
    final current = _auth.currentUser;
    if (current == null) throw Exception('User must be signed in');
    await createApplication(
      vacancyId: vacancyId,
      workerId: current.uid,
      employerId: employerId,
      vacancyTitle: vacancyTitle,
      extra: extra,
    );
  }

  /// Withdraw an application. Finds the doc and sets status to 'withdrawn' transactionally.
  /// Appends a timeline entry recording the withdrawal.
  Future<void> withdrawApplication({
    required String workerId,
    required String vacancyId,
  }) async {
    try {
      QuerySnapshot<Map<String, dynamic>> q = await _db
          .collection('applications')
          .where('workerId', isEqualTo: workerId)
          .where('vacancyId', isEqualTo: vacancyId)
          .limit(1)
          .get();

      String? docId;
      if (q.docs.isNotEmpty) {
        docId = q.docs.first.id;
      } else {
        final q2 = await _db.collection('applications').where('vacancyId', isEqualTo: vacancyId).limit(20).get();
        for (final doc in q2.docs) {
          final data = doc.data();
          final w1 = data['workerId'] as String?;
          final w2 = data['worker'] as String?;
          if (w1 == workerId || w2 == workerId) {
            docId = doc.id;
            break;
          }
        }
      }

      if (docId == null) {
        f.debugPrint('ApplicationService.withdrawApplication: application not found for worker=$workerId vacancy=$vacancyId');
        throw Exception('Application record not found');
      }

      // Use a concrete Timestamp for timeline entries (arrayUnion doesn't accept serverTimestamp())
      final timelineTs = Timestamp.fromDate(DateTime.now().toUtc());

      await _db.runTransaction((txn) async {
        final ref = _db.collection('applications').doc(docId);
        final snap = await txn.get(ref);
        if (!snap.exists) {
          throw Exception('Application already removed');
        }

        // Prepare timeline entry for withdrawal (use concrete Timestamp for 'ts')
        final timelineEntry = <String, dynamic>{
          'status': 'withdrawn',
          'label': 'Application withdrawn',
          'ts': timelineTs,
          'by': workerId,
          'note': '',
        };

        txn.update(ref, {
          'status': 'withdrawn',
          'updatedAt': FieldValue.serverTimestamp(),
          'withdrawnAt': FieldValue.serverTimestamp(),
          'withdrawnBy': workerId,
          // append timeline entry
          'timeline': FieldValue.arrayUnion([timelineEntry]),
        });
      });

      f.debugPrint('ApplicationService.withdrawApplication: success doc=$docId');
    } on FirebaseException catch (e, st) {
      f.debugPrint('ApplicationService.withdrawApplication FirebaseException: ${e.code} ${e.message}\n$st');
      throw Exception(e.message ?? 'Failed to withdraw application');
    } catch (err, st) {
      f.debugPrint('ApplicationService.withdrawApplication error: $err\n$st');
      throw Exception(err?.toString() ?? 'Failed to withdraw application');
    }
  }
}
