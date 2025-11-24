// Worker Home with improved vacancy cards showing employer avatar/name,
// description, date/time, location, dress code, rate, slots, deadline and an Apply flow.
// Employer profiles are loaded in batches for visible vacancies to reduce per-card reads.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../widgets/user_avatar_button.dart';
import '../../services/application_service.dart';
import 'vacancy_detail.dart';

/// Worker Home with:
///  • AppBar avatar menu (Wallet / Profile / Logout)
///  • Tabs: Open Vacancies / My Applications
///  • Apply to a vacancy -> creates `applications` doc (status: pending)
class WorkerHomeScreen extends StatefulWidget {
  const WorkerHomeScreen({super.key});

  @override
  State<WorkerHomeScreen> createState() => _WorkerHomeScreenState();
}

class _WorkerHomeScreenState extends State<WorkerHomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use theme colors so AppBar follows the app theme (primary / onPrimary).
    final appBarBg = Theme.of(context).colorScheme.primary;
    final appBarFg = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        // Allow space for avatar + name without overflow
        toolbarHeight: 72,
        title: const Text('FlexCrew – Crew'),
        backgroundColor: appBarBg,
        foregroundColor: appBarFg,
        actions: [
          // keep non-const so it rebuilds with proper context/resolved names
          UserAvatarButton(),
        ],
        bottom: TabBar(
          controller: _tabs,
          // Use theme's onPrimary for indicator/labels so contrast is correct
          indicatorColor: appBarFg,
          labelColor: appBarFg,
          unselectedLabelColor: appBarFg.withOpacity(.75),
          tabs: const [
            Tab(text: 'Open Vacancies'),
            Tab(text: 'My Applications'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OpenVacancies(
            onApplied: () => _tabs.animateTo(1),
          ),
          const _MyApplications(),
        ],
      ),
    );
  }
}

class _OpenVacancies extends StatefulWidget {
  const _OpenVacancies({required this.onApplied});

  final VoidCallback onApplied;

  @override
  State<_OpenVacancies> createState() => _OpenVacanciesState();
}

class _OpenVacanciesState extends State<_OpenVacancies> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _appSvc = ApplicationService();
  final Set<String> _optimisticRemoved = {};

  // In-memory cache: employerId -> { 'name': String?, 'avatar': String? }
  final Map<String, Map<String, String?>> _employerCache = {};
  // ids currently being loaded (to avoid duplicate batch requests)
  final Set<String> _loadingEmployerIds = {};

  static final _dateFmt = DateFormat.yMMMd();
  static final _dateTimeFmt = DateFormat.yMMMd().add_jm();

  // Batch load employers in chunks (Firestore whereIn limit = 10)
  Future<void> _batchLoadEmployers(List<String> employerIds) async {
    final idsToLoad = employerIds.where((id) => id.isNotEmpty && !_employerCache.containsKey(id) && !_loadingEmployerIds.contains(id)).toList();
    if (idsToLoad.isEmpty) return;

    for (final id in idsToLoad) _loadingEmployerIds.add(id);

    try {
      const chunkSize = 10;
      for (var i = 0; i < idsToLoad.length; i += chunkSize) {
        final chunk = idsToLoad.skip(i).take(chunkSize).toList();
        if (chunk.isEmpty) continue;

        // helper to extract name/avatar from a doc
        void _processDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
          final d = doc.data() ?? {};
          final name = (d['name'] ?? d['displayName'] ?? d['fullName'] ?? d['companyName']) as String?;
          final avatar = (d['avatarUrl'] ??
                  d['photoUrl'] ??
                  d['logoUrl'] ??
                  d['imageUrl'] ??
                  d['photo'] ??
                  d['logo'])
              as String?;
          final existing = _employerCache[doc.id];
          _employerCache[doc.id] = {
            'name': (name?.trim().isNotEmpty == true ? name : existing?['name'])?.toString(),
            'avatar': (avatar?.trim().isNotEmpty == true ? avatar : existing?['avatar'])?.toString(),
          };
          _loadingEmployerIds.remove(doc.id);
        }

        // Query users, employers, profiles
        final qUsers = await _db.collection('users').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in qUsers.docs) _processDoc(doc);

        final qEmployers = await _db.collection('employers').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in qEmployers.docs) _processDoc(doc);

        final qProfiles = await _db.collection('profiles').where(FieldPath.documentId, whereIn: chunk).get();
        for (final doc in qProfiles.docs) _processDoc(doc);

        for (final id in chunk) {
          if (!_employerCache.containsKey(id)) {
            _employerCache[id] = {'name': null, 'avatar': null};
            _loadingEmployerIds.remove(id);
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      for (final id in idsToLoad) _loadingEmployerIds.remove(id);
      // silent
    }
  }

  Future<void> _expressInterest(String vacancyId, Map<String, dynamic> vacancyData) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final employerId = vacancyData['employerId'] as String?;
    try {
      final dup = await _db
          .collection('applications')
          .where('vacancyId', isEqualTo: vacancyId)
          .where('workerId', isEqualTo: uid)
          .limit(1)
          .get();
      if (dup.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have already applied.')));
        widget.onApplied();
        return;
      }

      // Basic client validation: can't apply if closed/filled/slots 0 or past deadline.
      final status = (vacancyData['status'] as String?) ?? 'open';
      final slots = (vacancyData['slots'] as num?)?.toInt() ?? 0;
      final deadlineTs = vacancyData['applicationDeadline'] as Timestamp?;
      final deadline = deadlineTs?.toDate();
      final now = DateTime.now();
      if (status != 'open' || slots <= 0 || (deadline != null && deadline.isBefore(now))) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This vacancy is no longer accepting applications.')));
        return;
      }

      // Confirmation dialog for single-tap apply (prefill from profile/resume)
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Confirm application'),
          content: const Text('Apply with your profile and resume? This will send your application to the employer.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Apply')),
          ],
        ),
      );
      if (confirmed != true) return;

      await _appSvc.createApplication(workerId: uid, vacancyId: vacancyId, employerId: employerId);

      setState(() => _optimisticRemoved.add(vacancyId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent.')));
      widget.onApplied();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final msg = e.message ?? 'Failed to apply';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (e.code == 'already-exists') widget.onApplied();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to apply')));
    }
  }

  // Helper: format optional Timestamp -> readable string
  String _formatRange(Map<String, dynamic> data) {
    final sTs = data['startAt'];
    final eTs = data['endAt'];
    DateTime? s;
    DateTime? e;
    if (sTs is Timestamp) s = sTs.toDate();
    if (eTs is Timestamp) e = eTs.toDate();
    if (s != null && e != null) return '${_dateTimeFmt.format(s)} — ${_dateTimeFmt.format(e)}';
    if (s != null) return '${_dateFmt.format(s)}';
    return 'TBA';
  }

  Widget _buildVacancyCard(BuildContext context, DocumentSnapshot<Map<String, dynamic>> v, bool alreadyApplied) {
    final theme = Theme.of(context);
    final data = v.data() ?? {};
    final title = (data['title'] as String?) ?? 'Vacancy';
    final description = (data['description'] as String?) ?? '';
    final location = (data['location'] as String?) ?? '';
    final dress = (data['dressCode'] as String?) ?? '';
    final rate = data['ratePerHour'];
    final slots = (data['slots'] as num?)?.toInt() ?? 0;
    final status = (data['status'] as String?) ?? 'open';
    final deadlineTs = data['applicationDeadline'] as Timestamp?;
    final deadline = deadlineTs?.toDate();
    final now = DateTime.now();
    final isClosed = status != 'open' || slots <= 0 || (deadline != null && deadline.isBefore(now));

    final employerId = data['employerId'] as String?;
    final employerNameField = (data['employerName'] as String?) ?? (data['employer'] as String?);
    final employerAvatarField = (data['employerAvatarUrl'] as String?) ?? (data['employerAvatar'] as String?);

    String? employerName = employerNameField;
    String? employerAvatar = employerAvatarField;

    // If vacancy doesn't include employer details, check cache
    if ((employerName == null || employerName.isEmpty) && employerId != null && _employerCache.containsKey(employerId)) {
      employerName = _employerCache[employerId]?['name'];
    }
    if ((employerAvatar == null || employerAvatar.isEmpty) && employerId != null && _employerCache.containsKey(employerId)) {
      employerAvatar = _employerCache[employerId]?['avatar'];
    }

    // Compact chips
    final chips = <Widget>[];
    if (rate != null) chips.add(Chip(label: Text('\$${(rate is num ? rate.toString() : rate)} /hr'), avatar: const Icon(Icons.attach_money, size: 18)));
    if (location.isNotEmpty) chips.add(Chip(label: Text(location), avatar: const Icon(Icons.place, size: 18)));
    if (dress.isNotEmpty) chips.add(Chip(label: Text(dress), avatar: const Icon(Icons.checkroom, size: 18)));
    if (deadline != null) chips.add(Chip(label: Text('Apply by ${_dateFmt.format(deadline)}'), avatar: const Icon(Icons.event_busy, size: 18)));
    chips.add(Chip(label: Text('Slots: $slots'), avatar: const Icon(Icons.group, size: 18)));

    // logo rendering helper (updated to preserve colors and use contain)
    Widget _logoAvatar({double size = 40}) {
      if (employerAvatar != null && employerAvatar.isNotEmpty) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black12),
          ),
          child: ClipOval(
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.center,
              child: Image.network(
                employerAvatar,
                // no explicit width/height here so FittedBox controls scaling
                errorBuilder: (c, e, st) {
                  return CircleAvatar(
                    radius: size / 2,
                    backgroundColor: theme.colorScheme.surface,
                    child: Text(
                      (employerName != null && employerName.isNotEmpty) ? employerName[0] : (title.isNotEmpty ? title[0] : '?'),
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }

      // no image, show initial
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
          color: theme.colorScheme.primary.withOpacity(.08),
        ),
        child: Center(
          child: Text(
            (employerName != null && employerName.isNotEmpty) ? employerName[0] : (title.isNotEmpty ? title[0] : '?'),
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () {
        // Open vacancy details
        Navigator.of(context).push(MaterialPageRoute(
          builder: (c) => VacancyDetailScreen(vacancyId: v.id, vacancyData: data),
        ));
      },
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: avatar + (title + employer) + apply button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo avatar (preserve colors, avoid tint)
                  _logoAvatar(size: 40),
                  const SizedBox(width: 12),
                  // Title + employer name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          employerName ?? 'Employer',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.7)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Apply button - same height and vertically centered
                  SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: Icon(isClosed ? Icons.block : Icons.check_circle, size: 18),
                      label: Text(alreadyApplied ? 'Applied' : (isClosed ? 'Closed' : "I'm Interested")),
                      onPressed: alreadyApplied || isClosed
                          ? null
                          : () async {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applying...')));
                              await _expressInterest(v.id, data);
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Date/time range and short description
              Text(_formatRange(data), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              if (description.isNotEmpty)
                Text(description, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 10),
              // Chips row
              Wrap(spacing: 8, runSpacing: 6, children: chips),
              const SizedBox(height: 10),
              // Footer: small metadata with status and updatedAt
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.7)),
                    ),
                  ),
                  if (data['updatedAt'] is Timestamp)
                    Text(_dateFmt.format((data['updatedAt'] as Timestamp).toDate()), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(.6))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in.'));
    }

    final appsStream = _db.collection('applications').where('workerId', isEqualTo: uid).snapshots();

    final vacancies = _db
        .collection('vacancies')
        .where('status', isEqualTo: 'open')
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appsStream,
      builder: (context, appsSnap) {
        final appliedIds = <String>{};
        if (appsSnap.hasData) {
          for (final d in appsSnap.data!.docs) {
            final vid = d.data()['vacancyId'] as String?;
            if (vid != null) appliedIds.add(vid);
          }
        }
        appliedIds.addAll(_optimisticRemoved);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: vacancies,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return const Center(child: Text('No vacancies at the moment.'));
            }

            final docs = snap.data!.docs.where((d) => !appliedIds.contains(d.id)).toList();
            if (docs.isEmpty) return const Center(child: Text('No open vacancies'));

            // Collect unique employerIds missing from cache and trigger batch load
            final missingIds = <String>{};
            for (final d in docs) {
              final data = d.data() ?? {};
              final eid = data['employerId'] as String?;
              final name = (data['employerName'] as String?) ?? (data['employer'] as String?);
              if ((name == null || name.isEmpty) && eid != null && eid.isNotEmpty && !_employerCache.containsKey(eid) && !_loadingEmployerIds.contains(eid)) {
                missingIds.add(eid);
              }
            }
            if (missingIds.isNotEmpty) {
              // fire and forget; _batchLoadEmployers will call setState when done
              _batchLoadEmployers(missingIds.toList());
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final v = docs[i];
                final alreadyApplied = appliedIds.contains(v.id);
                return _buildVacancyCard(context, v, alreadyApplied);
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
    final entries = List<Map<String, dynamic>>.from(timeline.map((e) => Map<String, dynamic>.from(e as Map)));
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
      builder: (c) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Application timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No timeline entries yet.')),
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
                        final status = e['status'] ?? 'unknown';
                        final note = e['note'] ?? '';
                        return ListTile(
                          leading: Icon(_iconForStatus(status.toString())),
                          title: Text(_labelForStatus(status.toString())),
                          subtitle: Text(note),
                          trailing: Text(when, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _labelForStatus(String s) {
    switch (s) {
      case 'sent':
        return 'Sent';
      case 'viewed':
        return 'Viewed';
      case 'shortlisted':
        return 'Shortlisted';
      case 'interviewed':
        return 'Interviewed';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  IconData _iconForStatus(String s) {
    switch (s) {
      case 'sent':
        return Icons.send;
      case 'viewed':
        return Icons.remove_red_eye;
      case 'shortlisted':
        return Icons.star;
      case 'interviewed':
        return Icons.person_search;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Please sign in.'));
    }

    final appsStream = _db
        .collection('applications')
        .where('workerId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: appsStream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Center(child: Text('No applications yet.'));
        }

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
                : FirebaseFirestore.instance
                    .collection('vacancies')
                    .doc(vacancyId)
                    .get();

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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: status == 'shortlisted'
                        ? Chip(label: const Text('Shortlisted'), backgroundColor: Colors.yellow.shade700)
                        : null,
                    title: Text(title),
                    subtitle: Text(subtitle),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.timeline),
                          tooltip: 'Timeline',
                          onPressed: () => _showTimeline(context, a),
                        ),
                        TextButton(
                          onPressed: vacancyId == null
                              ? null
                              : () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (c) => AlertDialog(
                                      backgroundColor: Colors.white,
                                      title: const Text('Withdraw interest'),
                                      content: const Text('Are you sure you want to withdraw your interest?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                        TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Withdraw')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true && vacancyId != null) {
                                    await _withdraw(vacancyId);
                                  }
                                },
                          child: const Text('Withdraw'),
                        ),
                      ],
                    ),
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
