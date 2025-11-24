// Employer Home with vacancy management and improved vacancy form.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/notification_bell.dart';
import '../../widgets/user_avatar_button.dart';
import '../vacancies/vacancy_form.dart';

/// Employer Home with vacancy management:
///  - Create vacancy (FAB)
///  - Edit / Delete vacancy
///  - View applicants and update application status (accept/reject)
///  - Toggle vacancy status (open/closed/filled)
///  - Export applicants as CSV (copy to clipboard / show dialog)
class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> {
  final _db = FirebaseFirestore.instance;

  // Simple in-memory cache for worker profiles to reduce reads during a session.
  final Map<String, Map<String, dynamic>> _workerCache = {};

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  // ---------------- Vacancy CRUD helpers ----------------

  Future<void> _createVacancyDialog() async {
    await showVacancyFormDialog(context);
  }

  Future<void> _editVacancyDialog(String id, Map<String, dynamic> data) async {
    await showVacancyFormDialog(context, editId: id, initial: data);
  }

  Future<void> _confirmDelete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Delete vacancy'),
        content: const Text('Are you sure you want to delete this vacancy? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dCtx).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.collection('vacancies').doc(id).delete();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vacancy deleted')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  Future<void> _toggleVacancyStatus(String id, String current) async {
    final next = current == 'open' ? 'closed' : 'open';
    try {
      await _db.collection('vacancies').doc(id).set({'status': next, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Vacancy marked $next')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // ---------------- Applicant UX improvements ----------------

  /// Helper: chunk a list into pieces of size [size]
  List<List<T>> _chunk<T>(List<T> items, int size) {
    final out = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      out.add(items.sublist(i, i + size > items.length ? items.length : i + size));
    }
    return out;
  }

  /// Batch-load worker profiles for the given ids and populate cache.
  Future<void> _ensureWorkersCached(List<String> ids) async {
    final missing = ids.where((id) => !_workerCache.containsKey(id)).toSet().toList();
    if (missing.isEmpty) return;

    // Firestore 'whereIn' supports max 10 items per query — chunk if needed.
    final chunks = _chunk<String>(missing, 10);
    for (final chunk in chunks) {
      final snap = await _db.collection('workers').where(FieldPath.documentId, whereIn: chunk).get();
      for (final d in snap.docs) {
        _workerCache[d.id] = d.data();
      }
      // For any ids not found, store an empty map to avoid re-reads.
      final found = snap.docs.map((d) => d.id).toSet();
      for (final id in chunk) {
        if (!found.contains(id)) _workerCache[id] = {};
      }
    }
  }

  /// Show applicants in a bottom sheet. Uses batch worker reads and displays a small preview.
  Future<void> _showApplicants(String vacancyId) async {
    if (vacancyId.isEmpty) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetCtx) {
        return SizedBox(
          height: MediaQuery.of(sheetCtx).size.height * 0.75,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Applicants', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(sheetCtx).pop()),
                ]),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _db
                      .collection('applications')
                      .where('vacancyId', isEqualTo: vacancyId)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) return const Center(child: Text('No applications yet.'));

                    // Collect workerIds then ensure we have cached worker profiles.
                    final workerIds = docs.map((d) => (d.data()['workerId'] as String?) ?? '').where((s) => s.isNotEmpty).toSet().toList();

                    return FutureBuilder<void>(
                      future: _ensureWorkersCached(workerIds),
                      builder: (ctx, fSnap) {
                        if (fSnap.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, i) {
                            final d = docs[i];
                            final data = d.data();
                            final wid = (data['workerId'] as String?) ?? 'unknown';
                            final status = (data['status'] as String?) ?? 'pending';
                            final worker = _workerCache[wid] ?? {};
                            final displayName = (worker['name'] as String?) ?? wid;
                            final avatarUrl = (worker['photoUrl'] as String?) ?? '';
                            final resumeUrl = (worker['resumeUrl'] as String?) ?? '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl.isEmpty ? const Icon(Icons.person) : null,
                              ),
                              title: Text(displayName),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Status: $status'),
                                  if (resumeUrl.isNotEmpty) Text('Resume: available', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  try {
                                    if (v == 'accept') {
                                      // Accept: set application status to accepted and decrement vacancy slots in transaction
                                      await _db.runTransaction((tx) async {
                                        final vacRef = _db.collection('vacancies').doc(vacancyId);
                                        final vacSnap = await tx.get(vacRef);
                                        if (!vacSnap.exists) throw Exception('Vacancy gone');
                                        final slots = (vacSnap.data()?['slots'] as int?) ?? 0;
                                        final newSlots = (slots - 1).clamp(0, 999999);
                                        tx.update(vacRef, {
                                          'slots': newSlots,
                                          'status': newSlots == 0 ? 'filled' : vacSnap.data()?['status'] ?? 'open',
                                          'updatedAt': FieldValue.serverTimestamp(),
                                        });

                                        // Update application status
                                        final appRef = _db.collection('applications').doc(d.id);
                                        tx.update(appRef, {'status': 'accepted', 'updatedAt': FieldValue.serverTimestamp()});

                                        // Create in-app notification for the worker
                                        final notifRef = _db.collection('notifications').doc();
                                        tx.set(notifRef, {
                                          'userId': wid,
                                          'type': 'application-status',
                                          'title': 'Application accepted',
                                          'body': 'Your application was accepted',
                                          'data': {'applicationId': d.id, 'vacancyId': vacancyId, 'status': 'accepted'},
                                          'read': false,
                                          'createdAt': FieldValue.serverTimestamp(),
                                        });
                                      });
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application accepted')));
                                    } else if (v == 'reject') {
                                      await _db.collection('applications').doc(d.id).set({'status': 'rejected', 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

                                      // Create in-app notification for the worker about rejection
                                      await _db.collection('notifications').add({
                                        'userId': wid,
                                        'type': 'application-status',
                                        'title': 'Application update',
                                        'body': 'Your application was rejected',
                                        'data': {'applicationId': d.id, 'vacancyId': vacancyId, 'status': 'rejected'},
                                        'read': false,
                                        'createdAt': FieldValue.serverTimestamp(),
                                      });

                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application rejected')));
                                    } else if (v == 'message') {
                                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open chat / messaging (not implemented)')));
                                    }
                                  } catch (e) {
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(value: 'accept', child: Text('Accept')),
                                  const PopupMenuItem(value: 'reject', child: Text('Reject')),
                                  const PopupMenuItem(value: 'message', child: Text('Message')),
                                ],
                              ),
                              onTap: () {
                                // Optionally open worker profile / details screen
                                showDialog(
                                  context: context,
                                  builder: (pCtx) => AlertDialog(
                                    title: Text(displayName),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (avatarUrl.isNotEmpty) Center(child: Image.network(avatarUrl, width: 96, height: 96)),
                                        const SizedBox(height: 8),
                                        Text('Phone: ${(worker['phone'] as String?) ?? 'N/A'}'),
                                        const SizedBox(height: 6),
                                        Text('Skills: ${(worker['skills'] as String?) ?? 'N/A'}'),
                                        if (resumeUrl.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          TextButton(
                                            onPressed: () {
                                              // open resume in browser or webview
                                              Navigator.of(pCtx).pop();
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open resume (not implemented)')));
                                            },
                                            child: const Text('View resume'),
                                          )
                                        ],
                                      ],
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(pCtx).pop(), child: const Text('Close')),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }

  /// Export applicants as CSV:
  /// - Builds CSV of application rows with worker profile fields (name, phone, skills, status, appliedAt)
  /// - Copies CSV to clipboard and shows dialog with content for manual download/share
  Future<void> _exportApplicantsCsv(String vacancyId, String vacancyTitle) async {
    try {
      final appsSnap = await _db.collection('applications').where('vacancyId', isEqualTo: vacancyId).orderBy('createdAt').get();
      final apps = appsSnap.docs;
      if (apps.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No applicants to export')));
        return;
      }

      final workerIds = apps.map((d) => (d.data()['workerId'] as String?) ?? '').where((s) => s.isNotEmpty).toSet().toList();
      await _ensureWorkersCached(workerIds);

      final sb = StringBuffer();
      final headers = ['applicationId','workerId','name','phone','skills','status','appliedAt'];
      sb.writeln(headers.map((h) => '"${h.replaceAll('"','""')}"').join(','));

      for (final d in apps) {
        final data = d.data();
        final appId = d.id;
        final wid = (data['workerId'] as String?) ?? '';
        final worker = _workerCache[wid] ?? {};
        final name = (worker['name'] as String?) ?? '';
        final phone = (worker['phone'] as String?) ?? '';
        final skills = (worker['skills'] as String?) ?? '';
        final status = (data['status'] as String?) ?? '';
        final appliedAt = data['createdAt'] is Timestamp ? (data['createdAt'] as Timestamp).toDate().toIso8601String() : '';

        final row = [appId, wid, name, phone, skills, status, appliedAt]
            .map((c) => '"${(c ?? '').toString().replaceAll('"', '""')}"')
            .join(',');
        sb.writeln(row);
      }

      final csv = sb.toString();

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: csv));

      // Show dialog with CSV preview and quick copy/share instructions.
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dCtx) => AlertDialog(
          title: Text('Exported applicants for "$vacancyTitle"'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('CSV copied to clipboard. Paste into a text editor or spreadsheet (File ? Import).'),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: SelectableText(csv),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Widget _vacancyCard(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final title = (data['title'] as String?) ?? 'Vacancy';
    final status = (data['status'] as String?) ?? 'open';
    final slots = data['slots'] as int? ?? 1;

    return Card(
      elevation: 0,
      color: Colors.orange.withOpacity(.03),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title),
        subtitle: Text('Status: $status • Slots: $slots'),
        trailing: PopupMenuButton<String>(
          onSelected: (v) async {
            final id = doc.id;
            if (v == 'edit') {
              await _editVacancyDialog(id, data);
            } else if (v == 'applicants') {
              await _showApplicants(id);
            } else if (v == 'toggle') {
              await _toggleVacancyStatus(id, status);
            } else if (v == 'export') {
              await _exportApplicantsCsv(id, title);
            } else if (v == 'delete') {
              await _confirmDelete(id);
            }
          },
          itemBuilder: (c) => [
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            const PopupMenuItem(value: 'applicants', child: Text('View applicants')),
            PopupMenuItem(value: 'toggle', child: Text(status == 'open' ? 'Close vacancy' : 'Re-open vacancy')),
            const PopupMenuItem(value: 'export', child: Text('Export applicants (CSV)')),
            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ),
        onTap: () => _showApplicants(doc.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlexCrew – Employer'),
        actions: const [
          NotificationBell(),
          SizedBox(width: 6),
          UserAvatarButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createVacancyDialog,
        label: const Text('Post Vacancy'),
        icon: const Icon(Icons.add),
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in.'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('vacancies')
                  .where('employerId', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return const Center(child: Text('No vacancies yet.'));
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _vacancyCard(docs[i]),
                );
              },
            ),
    );
  }
}

