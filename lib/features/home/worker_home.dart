// Worker home: Open Vacancies / My Applications with apply flow and employer batch lookups.
//
// This file provides two tabs:
//  - Open Vacancies: shows vacancies the worker hasn't applied to yet.
//  - My Applications: shows worker's applications and timeline.
//
// Uses ApplicationService for create/withdraw operations and keeps a small employer cache
// to reduce repeated user/profile lookups.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' as f;
import '../../widgets/user_avatar_button.dart';
import '../../widgets/shimmer_placeholder.dart';
import '../../widgets/chip_with_log.dart';
import '../../services/application_service.dart';
import '../vacancies/vacancy_detail_screen.dart';

/// Shared employer cache that can be reused across screens while the app is running.
final Map<String, Map<String, String?>> _sharedEmployerCache = {};
final Set<String> _sharedLoadingEmployerIds = {};

class WorkerHomeScreen extends StatelessWidget {
  const WorkerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appBarBg = Theme.of(context).colorScheme.primary;
    final appBarFg = Theme.of(context).colorScheme.onPrimary;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 72,
          title: const Text('FlexCrew - Crew'),
          backgroundColor: appBarBg,
          foregroundColor: appBarFg,
          actions: const [UserAvatarButton()],
          bottom: TabBar(
            indicatorColor: appBarFg,
            labelColor: appBarFg,
            unselectedLabelColor: appBarFg.withOpacity(.75),
            tabs: const [
              Tab(text: 'Open Vacancies'),
              Tab(text: 'My Applications'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _OpenVacancies(),
            _MyApplications(),
          ],
        ),
      ),
    );
  }
}

class _OpenVacancies extends StatefulWidget {
  const _OpenVacancies();

  @override
  State<_OpenVacancies> createState() => _OpenVacanciesState();
}

class _OpenVacanciesState extends State<_OpenVacancies> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _appSvc = ApplicationService();

  final Set<String> _optimisticRemoved = {};
  final Map<String, Map<String, String?>> _employerCache = {};
  final Set<String> _loadingEmployerIds = {};

  static final _dateFmt = DateFormat.yMMMd();
  static final _dateTimeFmt = DateFormat.yMMMd().add_jm();

  Future<void> _batchLoadEmployers(List<String> ids) async {
    final toLoad = ids.where((id) => id.isNotEmpty && !_employerCache.containsKey(id) && !_loadingEmployerIds.contains(id)).toList();
    if (toLoad.isEmpty) return;
    for (final id in toLoad) _loadingEmployerIds.add(id);

    try {
      const chunkSize = 10;
      for (var i = 0; i < toLoad.length; i += chunkSize) {
        final chunk = toLoad.skip(i).take(chunkSize).toList();
        if (chunk.isEmpty) continue;

        final qUsers = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        final qEmployers = await _db.collection('employers').where(FieldPath.documentId, whereIn: chunk).get();
        final qProfiles = await _db.collection('profiles').where(FieldPath.documentId, whereIn: chunk).get();

        void process(DocumentSnapshot<Map<String, dynamic>> doc) {
          final d = doc.data() ?? {};
          final name = (d['name'] ?? d['displayName'] ?? d['fullName'] ?? d['companyName']) as String?;
          final avatar = (d['avatarUrl'] ?? d['photoUrl'] ?? d['logoUrl'] ?? d['imageUrl']) as String?;
          final existing = _employerCache[doc.id];
          _employerCache[doc.id] = {
            'name': (name?.trim().isNotEmpty == true ? name : existing?['name'])?.toString(),
            'avatar': (avatar?.trim().isNotEmpty == true ? avatar : existing?['avatar'])?.toString(),
          };
          _sharedEmployerCache[doc.id] = _employerCache[doc.id] ?? {'name': null, 'avatar': null};
          _loadingEmployerIds.remove(doc.id);
          _sharedLoadingEmployerIds.remove(doc.id);
        }

        for (final d in qUsers.docs) process(d);
        for (final d in qEmployers.docs) process(d);
        for (final d in qProfiles.docs) process(d);

        for (final id in chunk) {
          _loadingEmployerIds.remove(id);
          _sharedLoadingEmployerIds.remove(id);
          _employerCache.putIfAbsent(id, () => {'name': null, 'avatar': null});
          _sharedEmployerCache.putIfAbsent(id, () => {'name': null, 'avatar': null});
        }
      }

      if (mounted) setState(() {});
    } catch (e, st) {
      // Best-effort: clear loading flags on error.
      for (final id in toLoad) {
        _loadingEmployerIds.remove(id);
        _sharedLoadingEmployerIds.remove(id);
      }
      // Log for debugging
      debugPrint('Batch load employers failed: $e\n$st');
    }
  }

  Future<void> _expressInterest(String vacancyId, Map<String, dynamic> vacancyData) async {
    // confirm then call service (expressInterest reads currentUser internally)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirm Application'),
        content: const Text('Apply with your profile and resume?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _appSvc.expressInterest(vacancyId: vacancyId, employerId: vacancyData['employerId'] as String?);
      if (!mounted) return;
      setState(() => _optimisticRemoved.add(vacancyId));
      DefaultTabController.of(context)?.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent.')));
    } on FirebaseException catch (e, st) {
      debugPrint('APPLY FirebaseException: ${e.code} ${e.message}\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to apply: ${e.message ?? e.code}')));
    } catch (e, st) {
      debugPrint('APPLY error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to apply: $e')));
    }
  }

  String _formatRange(Map<String, dynamic> data) {
    Timestamp? s = data['startAt'] as Timestamp?;
    Timestamp? e = data['endAt'] as Timestamp?;
    final shift = data['shift'];
    if (s == null && shift is Map && shift['startAt'] is Timestamp) s = shift['startAt'] as Timestamp?;
    if (e == null && shift is Map && shift['endAt'] is Timestamp) e = shift['endAt'] as Timestamp?;
    if (s != null && e != null) return '${_dateTimeFmt.format(s.toDate())} - ${_dateTimeFmt.format(e.toDate())}';
    if (s != null) return _dateTimeFmt.format(s.toDate());
    return 'TBA';
  }

  String _extractLocationString(Map<String, dynamic> data) {
    final locRaw = data['location'];
    if (locRaw == null) return '';
    if (locRaw is String) return locRaw.trim();
    if (locRaw is Map) {
      final v = locRaw['name'] ?? locRaw['displayName'];
      if (v is String && v.trim().isNotEmpty) return v.trim();
      final lat = locRaw['latitude'] ?? locRaw['lat'];
      final lng = locRaw['longitude'] ?? locRaw['lng'] ?? locRaw['lon'];
      if (lat != null && lng != null) return 'Location ${lat.toString()}, ${lng.toString()}';
    }
    try {
      final s = locRaw.toString();
      return s.trim().isNotEmpty ? s.trim() : '';
    } catch (_) {
      return '';
    }
  }

  String _extractDressCode(Map<String, dynamic> data) {
    final v = data['dressCode'] ?? data['dress'] ?? data['dress_code'];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return '';
  }

  Widget _vacancyCard(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc, bool alreadyApplied) {
    final data = doc.data() ?? {};
    final title = (data['title'] as String?) ?? 'Vacancy';
    final desc = (data['description'] as String?) ?? '';
    final location = _extractLocationString(data);
    final dressCode = _extractDressCode(data);
    final rate = data['ratePerHour'];
    final slots = (data['slots'] is num) ? (data['slots'] as num).toInt() : int.tryParse((data['slots'] ?? '0').toString()) ?? 0;
    final status = (data['status'] as String?) ?? 'open';
    final deadline = (data['applicationDeadline'] as Timestamp?)?.toDate();
    final isClosed = status != 'open' || slots <= 0 || (deadline != null && deadline.isBefore(DateTime.now()));

    final employerId = data['employerId'] as String?;
    String? employerName = (data['employerName'] as String?) ?? (data['employer'] as String?);
    String? employerAvatar = (data['employerAvatarUrl'] as String?) ?? (data['employerAvatar'] as String?);

    if ((employerName == null || employerName.isEmpty) && employerId != null) {
      if (_employerCache.containsKey(employerId)) employerName = _employerCache[employerId]?['name'];
      if ((employerName == null || employerName.isEmpty) && _sharedEmployerCache.containsKey(employerId)) employerName = _sharedEmployerCache[employerId]?['name'];
    }
    if ((employerAvatar == null || employerAvatar.isEmpty) && employerId != null) {
      if (_employerCache.containsKey(employerId)) employerAvatar = _employerCache[employerId]?['avatar'];
      if ((employerAvatar == null || employerAvatar.isEmpty) && _sharedEmployerCache.containsKey(employerId)) employerAvatar = _sharedEmployerCache[employerId]?['avatar'];
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (employerId != null && _loadingEmployerIds.contains(employerId))
              ShimmerPlaceholder.circle(size: 44, baseColor: Theme.of(context).colorScheme.surfaceVariant, highlightColor: Theme.of(context).colorScheme.surface)
            else
              CircleAvatar(
                radius: 22,
                backgroundImage: (employerAvatar != null && employerAvatar.isNotEmpty) ? NetworkImage(employerAvatar) : null,
                child: (employerAvatar == null || employerAvatar.isEmpty) ? Text((employerName ?? title)[0]) : null,
              ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              if (employerName != null) Text(employerName, style: Theme.of(context).textTheme.bodySmall),
            ])),
            FilledButton.icon(
              icon: Icon(isClosed ? Icons.block : Icons.check_circle, size: 18),
              label: Text(alreadyApplied ? 'Applied' : (isClosed ? 'Closed' : "I'm Interested")),
              onPressed: (alreadyApplied || isClosed) ? null : () => _expressInterest(doc.id, data),
            ),
          ]),
          const SizedBox(height: 8),
          Text(_formatRange(data), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          if (desc.isNotEmpty) Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (rate != null) ChipWithLog(label: Text('\$${rate.toString()} /hr'), avatar: const Icon(Icons.attach_money, size: 16)),
            if (location.isNotEmpty) ChipWithLog(label: Text(location), avatar: const Icon(Icons.place, size: 16)),
            if (dressCode.isNotEmpty) ChipWithLog(label: Text(dressCode), avatar: const Icon(Icons.checkroom, size: 16)),
            ChipWithLog(label: Text('Slots: $slots'), avatar: const Icon(Icons.group, size: 16)),
            if (deadline != null) ChipWithLog(label: Text('Apply by ${_dateFmt.format(deadline)}'), avatar: const Icon(Icons.event_busy, size: 16)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final appsStream = _db.collection('applications').where('workerId', isEqualTo: uid).snapshots();
    final vacanciesStream = _db.collection('vacancies').where('status', isEqualTo: 'open').orderBy('createdAt', descending: true).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appsStream,
      builder: (context, appsSnap) {
        final applied = <String>{};
        if (appsSnap.hasData) {
          for (final d in appsSnap.data!.docs) {
            final data = d.data();
            final st = (data['status'] as String?) ?? '';
            if (st == 'withdrawn' || st == 'deleted') continue;
            final vid = data['vacancyId'] as String?;
            if (vid != null) applied.add(vid);
          }
        }
        applied.addAll(_optimisticRemoved);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: vacanciesStream,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No open vacancies'));

            final docs = snap.data!.docs.where((d) => !applied.contains(d.id)).toList();

            final missing = <String>{};
            for (final d in docs) {
              final data = d.data() ?? {};
              final eid = data['employerId'] as String?;
              final name = (data['employerName'] as String?) ?? (data['employer'] as String?);
              if ((name == null || name.isEmpty) && eid != null && !_employerCache.containsKey(eid) && !_loadingEmployerIds.contains(eid)) missing.add(eid);
            }
            if (missing.isNotEmpty) _batchLoadEmployers(missing.toList());

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final d = docs[i];
                final alreadyApplied = applied.contains(d.id);
                return _vacancyCard(context, d, alreadyApplied);
              },
            );
          },
        );
      },
    );
  }
}

class _MyApplications extends StatefulWidget {
  const _MyApplications();

  @override
  State<_MyApplications> createState() => _MyApplicationsState();
}

class _MyApplicationsState extends State<_MyApplications> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _appSvc = ApplicationService();

  void _showTimeline(BuildContext context, Map<String, dynamic> application) {
    final timeline = (application['timeline'] as List<dynamic>?) ?? [];
    final entries = timeline.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    entries.sort((a, b) {
      final ta = a['ts'] as Timestamp?;
      final tb = b['ts'] as Timestamp?;
      if (ta == null && tb == null) return 0;
      if (ta == null) return -1;
      if (tb == null) return 1;
      return ta.compareTo(tb);
    });

    showModalBottomSheet(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Application timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            if (entries.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No timeline entries yet.')),
            if (entries.isNotEmpty)
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final e = entries[i];
                    final ts = e['ts'] as Timestamp?;
                    final when = ts != null ? DateFormat.yMMMd().add_jm().format(ts.toDate()) : '—';
                    final label = e['label'] ?? e['status'] ?? 'update';
                    final note = e['note'] ?? '';
                    return ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(label.toString()),
                      subtitle: Text(note.toString()),
                      trailing: Text(when, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    );
                  },
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _applicationCard(BuildContext context, Map<String, dynamic> application, Map<String, dynamic>? vacancyData, String? vacancyId, String applicationId) {
    final status = (application['status'] as String?) ?? 'pending';
    final createdAt = (application['createdAt'] as Timestamp?)?.toDate();

    // Ensure title and description are non-null and trimmed before use to satisfy null-safety.
    final rawTitle = vacancyData != null ? (vacancyData['title'] as String?) : (application['vacancyTitle'] as String?);
    final title = (rawTitle?.trim().isNotEmpty == true) ? rawTitle!.trim() : 'Applied role';

    final desc = vacancyData != null ? (vacancyData['description'] as String?) ?? '' : '';
    final rate = vacancyData != null ? vacancyData['ratePerHour'] : application['ratePerHour'];
    final location = vacancyData != null ? (vacancyData['location'] as String?) ?? '' : '';
    final deadline = vacancyData != null ? (vacancyData['applicationDeadline'] as Timestamp?)?.toDate() : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(radius: 22, child: Text(title.isNotEmpty ? title[0] : 'A')),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              if (createdAt != null) Text(DateFormat.yMMMd().add_jm().format(createdAt), style: Theme.of(context).textTheme.bodySmall),
            ])),
            Column(mainAxisSize: MainAxisSize.min, children: [
              if (status == 'shortlisted') ChipWithLog(label: const Text('Shortlisted'), backgroundColorStart: Colors.yellow.shade700, backgroundColorEnd: Colors.orange.shade700, avatar: const Icon(Icons.star, size: 16)),
              const SizedBox(height: 6),
              OutlinedButton.icon(onPressed: () => _showTimeline(context, application), icon: const Icon(Icons.timeline, size: 18), label: const Text('Timeline')),
            ]),
          ]),
          const SizedBox(height: 8),
          if (desc.isNotEmpty) Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (rate != null) ChipWithLog(label: Text('\$${rate.toString()} /hr'), avatar: const Icon(Icons.attach_money, size: 16)),
            if (location.isNotEmpty) ChipWithLog(label: Text(location), avatar: const Icon(Icons.place, size: 16)),
            if (deadline != null) ChipWithLog(label: Text('Apply by ${DateFormat.yMMMd().format(deadline)}'), avatar: const Icon(Icons.event_busy, size: 16)),
            ChipWithLog(label: Text('Status: $status'), avatar: const Icon(Icons.info_outline, size: 16)),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            // Use application document id as primary identifier; pass vacancyId as hint.
            TextButton(
              onPressed: applicationId.isEmpty
                  ? null
                  : () {
                      // Immediate debug feedback so we know the handler fired
                      final msg = 'Withdraw pressed — applicationId=$applicationId vacancyId=$vacancyId';
                      debugPrint(msg);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
                      // Then run the normal flow
                      _withdraw(applicationId, vacancyId: vacancyId);
                    },
              child: const Text('Withdraw'),
            ),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final appsStream = _db.collection('applications').where('workerId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No applications yet.'));

        final docs = snap.data!.docs.where((d) {
          final data = d.data();
          final s = (data['status'] as String?) ?? '';
          if (s == 'withdrawn' || s == 'deleted') return false;
          return true;
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('No applications yet.'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final app = doc.data();
            final applicationId = doc.id;
            final vacancyId = app['vacancyId'] as String?;
            final futureVacancy = (vacancyId == null) ? null : FirebaseFirestore.instance.collection('vacancies').doc(vacancyId).get();
            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: futureVacancy,
              builder: (context, vSnap) {
                Map<String, dynamic>? vacancyData;
                if (vSnap.hasData && vSnap.data?.data() != null) vacancyData = vSnap.data!.data();
                return _applicationCard(context, app, vacancyData, vacancyId, applicationId);
              },
            );
          },
        );
      },
    );
  }

  /// Unified withdraw helper.
  /// Primary path: prefer using ApplicationService.withdrawApplication by vacancyId.
  /// Fallback: update the application document directly using known applicationId.
  Future<void> _withdraw(String applicationId, {String? vacancyId}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      debugPrint('Withdraw: no authenticated user');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Withdraw Interest'),
        content: const Text('Are you sure you want to withdraw your interest?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Withdraw')),
        ],
      ),
    );
    if (confirmed != true) return;

    debugPrint('Withdraw: starting for applicationId=$applicationId vacancyId=$vacancyId worker=$uid');

    try {
      // On web the cloud_firestore_web / interop layer has produced JS/Dart boxing errors.
      // Use the local transactional fallback on web to avoid the service query path.
      if (f.kIsWeb) {
        if (applicationId.isEmpty) {
          throw Exception('Missing applicationId for web fallback path');
        }

        await _db.runTransaction((txn) async {
          final ref = _db.collection('applications').doc(applicationId);
          final snap = await txn.get(ref);
          if (!snap.exists) throw Exception('Application not found');
          final data = snap.data() ?? {};
          final w1 = data['workerId'] as String?;
          final w2 = data['worker'] as String?;
          if (w1 != uid && w2 != uid) throw Exception('Not allowed');

          final timelineEntry = <String, dynamic>{
            'status': 'withdrawn',
            'label': 'Application withdrawn',
            'ts': FieldValue.serverTimestamp(),
            'by': uid,
            'note': '',
          };

          txn.update(ref, {
            'status': 'withdrawn',
            'updatedAt': FieldValue.serverTimestamp(),
            'withdrawnAt': FieldValue.serverTimestamp(),
            'withdrawnBy': uid,
            'timeline': FieldValue.arrayUnion([timelineEntry]),
          });
        });
        debugPrint('Withdraw: web fallback doc update succeeded for applicationId=$applicationId');
      } else {
        // Native / non-web: use the ApplicationService path (keeps central logic)
        if (vacancyId != null && vacancyId.isNotEmpty) {
          await _appSvc.withdrawApplication(workerId: uid, vacancyId: vacancyId);
          debugPrint('Withdraw: service path succeeded for vacancyId=$vacancyId');
        } else {
          // If vacancyId missing on non-web, fall back to applicationId transactional update
          await _db.runTransaction((txn) async {
            final ref = _db.collection('applications').doc(applicationId);
            final snap = await txn.get(ref);
            if (!snap.exists) throw Exception('Application not found');
            final data = snap.data() ?? {};
            final w1 = data['workerId'] as String?;
            final w2 = data['worker'] as String?;
            if (w1 != uid && w2 != uid) throw Exception('Not allowed');

            final timelineEntry = <String, dynamic>{
              'status': 'withdrawn',
              'label': 'Application withdrawn',
              'ts': FieldValue.serverTimestamp(),
              'by': uid,
              'note': '',
            };

            txn.update(ref, {
              'status': 'withdrawn',
              'updatedAt': FieldValue.serverTimestamp(),
              'withdrawnAt': FieldValue.serverTimestamp(),
              'withdrawnBy': uid,
              'timeline': FieldValue.arrayUnion([timelineEntry]),
            });
          });
          debugPrint('Withdraw: fallback doc update succeeded for applicationId=$applicationId');
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interest withdrawn')));
      setState(() {});
    } on FirebaseException catch (e, st) {
      debugPrint('Withdraw FirebaseException: ${e.code} ${e.message}\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to withdraw: ${e.message ?? e.code}')));
    } catch (e, st) {
      debugPrint('Withdraw error: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Withdraw failed: ${e.toString()}')));
    }
  }
}
