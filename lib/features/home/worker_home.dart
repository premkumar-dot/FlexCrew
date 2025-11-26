// Worker home: Open Vacancies / My Applications with apply flow and employer batch lookups.
// Simplified to use DefaultTabController to avoid TabController lifecycle issues.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/user_avatar_button.dart';
import '../../services/application_service.dart';
import 'vacancy_detail.dart';

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
          final avatar = (d['avatarUrl'] ?? d['photoUrl'] ?? d['logoUrl'] ?? d['imageUrl'] ?? d['photo'] ?? d['logo']) as String?;
          final existing = _employerCache[doc.id];
          _employerCache[doc.id] = {
            'name': (name?.trim().isNotEmpty == true ? name : existing?['name'])?.toString(),
            'avatar': (avatar?.trim().isNotEmpty == true ? avatar : existing?['avatar'])?.toString(),
          };
          _loadingEmployerIds.remove(doc.id);
        }

        for (final d in qUsers.docs) process(d);
        for (final d in qEmployers.docs) process(d);
        for (final d in qProfiles.docs) process(d);

        for (final id in chunk) {
          if (!_employerCache.containsKey(id)) {
            _employerCache[id] = {'name': null, 'avatar': null};
            _loadingEmployerIds.remove(id);
          }
        }
      }

      if (mounted) setState(() {});
    } catch (_) {
      for (final id in toLoad) _loadingEmployerIds.remove(id);
    }
  }

  Future<void> _expressInterest(String vacancyId, Map<String, dynamic> vacancyData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final employerId = vacancyData['employerId'] as String?;
    debugPrint('APPLY START: vacancy=$vacancyId worker=$uid employer=$employerId');

    final dup = await _db.collection('applications').where('vacancyId', isEqualTo: vacancyId).where('workerId', isEqualTo: uid).limit(1).get();
    if (dup.docs.isNotEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have already applied.')));
      // switch to My Applications tab
      DefaultTabController.of(context)?.animateTo(1);
      return;
    }

    final status = (vacancyData['status'] as String?) ?? 'open';
    final slots = (vacancyData['slots'] as num?)?.toInt() ?? 0;
    final deadline = (vacancyData['applicationDeadline'] as Timestamp?)?.toDate();
    if (status != 'open' || slots <= 0 || (deadline != null && deadline.isBefore(DateTime.now()))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This vacancy is not accepting applications.')));
      return;
    }

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
      await _appSvc.createApplication(workerId: uid, vacancyId: vacancyId, employerId: employerId);
      setState(() => _optimisticRemoved.add(vacancyId));
      DefaultTabController.of(context)?.animateTo(1);
      debugPrint('APPLY SUCCESS: vacancy=$vacancyId');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent.')));
    } on FirebaseException catch (e) {
      debugPrint('APPLY ERROR: ${e.code} ${e.message}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to apply')));
    } catch (e) {
      debugPrint('APPLY EXCEPTION: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to apply')));
    }
  }

  String _formatRange(Map<String, dynamic> data) {
    final s = data['startAt'] as Timestamp?;
    final e = data['endAt'] as Timestamp?;
    if (s != null && e != null) return '${_dateTimeFmt.format(s.toDate())} - ${_dateTimeFmt.format(e.toDate())}';
    if (s != null) return _dateTimeFmt.format(s.toDate());
    return 'TBA';
  }

  Widget _vacancyCard(BuildContext context, DocumentSnapshot<Map<String, dynamic>> doc, bool alreadyApplied) {
    final data = doc.data() ?? {};
    final title = (data['title'] as String?) ?? 'Vacancy';
    final desc = (data['description'] as String?) ?? '';
    final location = (data['location'] as String?) ?? '';
    final rate = data['ratePerHour'];
    final slots = (data['slots'] as num?)?.toInt() ?? 0;
    final status = (data['status'] as String?) ?? 'open';
    final deadline = (data['applicationDeadline'] as Timestamp?)?.toDate();
    final isClosed = status != 'open' || slots <= 0 || (deadline != null && deadline.isBefore(DateTime.now()));

    final employerId = data['employerId'] as String?;
    String? employerName = (data['employerName'] as String?) ?? (data['employer'] as String?);
    String? employerAvatar = (data['employerAvatarUrl'] as String?) ?? (data['employerAvatar'] as String?);

    if ((employerName == null || employerName.isEmpty) && employerId != null && _employerCache.containsKey(employerId)) {
      employerName = _employerCache[employerId]?['name'];
      employerAvatar = _employerCache[employerId]?['avatar'];
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(
              radius: 22,
              backgroundImage: (employerAvatar != null && employerAvatar.isNotEmpty) ? NetworkImage(employerAvatar) : null,
              child: (employerAvatar == null || employerAvatar.isEmpty) ? Text((employerName ?? title)[0]) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(employerName ?? 'Employer', style: Theme.of(context).textTheme.bodySmall),
            ])),
            FilledButton.icon(
              icon: Icon(isClosed ? Icons.block : Icons.check_circle, size: 18),
              label: Text(alreadyApplied ? 'Applied' : (isClosed ? 'Closed' : "I'm Interested")),
              onPressed: (alreadyApplied || isClosed) ? null : () async {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applying...')));
                await _expressInterest(doc.id, data);
              },
            ),
          ]),
          const SizedBox(height: 8),
          Text(_formatRange(data), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          if (desc.isNotEmpty) Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            if (rate != null) Chip(label: Text('\$${rate.toString()} /hr')),
            if (location.isNotEmpty) Chip(label: Text(location)),
            Chip(label: Text('Slots: $slots')),
            if (deadline != null) Chip(label: Text('Apply by ${_dateFmt.format(deadline)}')),
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
            final vid = d.data()['vacancyId'] as String?; if (vid != null) applied.add(vid);
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
  final Set<String> _optimisticWithdrawn = {};

  Future<void> _withdraw(String vacancyId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _appSvc.withdrawApplication(workerId: uid, vacancyId: vacancyId);
      setState(() => _optimisticWithdrawn.add(vacancyId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Interest withdrawn')));
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to withdraw')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to withdraw')));
    }
  }

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
                    final label = e['status'] ?? 'update';
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
          final vid = d.data()['vacancyId'] as String? ?? '';
          return !_optimisticWithdrawn.contains(vid);
        }).toList();

        if (docs.isEmpty) return const Center(child: Text('No applications yet.'));

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final a = doc.data();
            final status = (a['status'] as String?) ?? 'pending';
            final createdAt = a['createdAt'];
            final vacancyId = a['vacancyId'] as String?;

            final futureVacancy = vacancyId == null
                ? null
                : FirebaseFirestore.instance.collection('vacancies').doc(vacancyId).get();

            return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(

              future: futureVacancy,
              builder: (context, vSnap) {
                String title = 'Applied role';
                if (vSnap.hasData && vSnap.data?.data() != null) {
                  title = (vSnap.data!.data()!['title'] as String?) ?? title;
                }

                final subtitle = (createdAt is Timestamp)
                    ? 'Status: $status • ${DateFormat.yMMMd().add_jm().format(createdAt.toDate())}'
                    : 'Status: $status';

                return Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: status == 'shortlisted' ? Chip(label: const Text('Shortlisted'), backgroundColor: Colors.yellow.shade700) : null,
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.timeline), tooltip: 'Timeline', onPressed: () => _showTimeline(context, a)),
                      TextButton(
                        onPressed: vacancyId == null ? null : () async {
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
                          if (confirmed == true && vacancyId != null) await _withdraw(vacancyId);
                        },
                        child: const Text('Withdraw'),
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
