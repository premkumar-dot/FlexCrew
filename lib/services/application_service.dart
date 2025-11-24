// Reusable ApplicationService moved out of the home screen for reuse.
import 'package:cloud_firestore/cloud_firestore.dart';

class ApplicationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String docIdFor(String workerId, String vacancyId) => '${workerId}_$vacancyId';

  Future<void> createApplication({
    required String workerId,
    required String vacancyId,
    required String? employerId,
  }) async {
    final userSnap = await _db.collection('users').doc(workerId).get();
    final userData = userSnap.exists ? (userSnap.data() ?? {}) : {};
    final profile = userData['profile'] ?? userData;

    final id = docIdFor(workerId, vacancyId);
    final ref = _db.collection('applications').doc(id);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (snap.exists) {
        throw FirebaseException(
            plugin: 'app', code: 'already-exists', message: 'Application already exists.');
      }
      tx.set(ref, {
        'vacancyId': vacancyId,
        'workerId': workerId,
        'employerId': employerId,
        'status': 'sent',
        'workerProfile': profile,
        'resume': userData['resume'] ?? null,
        'timeline': [
          {
            'status': 'sent',
            'by': workerId,
            'note': 'Application sent',
            'ts': FieldValue.serverTimestamp(),
          }
        ],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> withdrawApplication({
    required String workerId,
    required String vacancyId,
  }) async {
    final id = docIdFor(workerId, vacancyId);
    final ref = _db.collection('applications').doc(id);
    final snap = await ref.get();
    if (snap.exists) {
      final data = snap.data() as Map<String, dynamic>? ?? {};
      if (data['workerId'] != workerId) {
        throw FirebaseException(
            plugin: 'app', code: 'permission-denied', message: 'Not owner of application.');
      }
      await ref.delete();
      return;
    }

    final q = await _db
        .collection('applications')
        .where('workerId', isEqualTo: workerId)
        .where('vacancyId', isEqualTo: vacancyId)
        .get();
    for (final d in q.docs) {
      await d.reference.delete();
    }
  }
}
