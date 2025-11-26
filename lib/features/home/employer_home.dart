// Employer Home — simple tabs: My Vacancies / Applications
// Scaffolded to match project patterns (theme, avatar button, vacancy detail).
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../widgets/user_avatar_button.dart';
import '../../widgets/notification_bell.dart';
import 'vacancy_detail.dart';
import '../../services/application_service.dart';

class EmployerHomeScreen extends StatefulWidget {
  const EmployerHomeScreen({super.key});

  @override
  State<EmployerHomeScreen> createState() => _EmployerHomeScreenState();
}

class _EmployerHomeScreenState extends State<EmployerHomeScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _appSvc = ApplicationService();

  static final _dateFmt = DateFormat.yMMMd();

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
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: const Text('FlexCrew – Employer'),
        backgroundColor: primary,
        foregroundColor: onPrimary,
        actions: const [NotificationBell(), UserAvatarButton()],
        bottom: TabBar(
          controller: _tabs,
          labelColor: onPrimary,
          unselectedLabelColor: onPrimary.withOpacity(.85),
          indicatorColor: onPrimary,
          tabs: const [
            Tab(text: 'My Vacancies'),
            Tab(text: 'Applications'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        onPressed: () {
          context.pushNamed('vacancy-create');
        },
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _MyVacanciesSection(db: _db, auth: _auth),
          _EmployerApplicationsSection(db: _db, auth: _auth, appSvc: _appSvc),
        ],
      ),
    );
  }
}

class _MyVacanciesSection extends StatelessWidget {
  const _MyVacanciesSection({required this.db, required this.auth});

  final FirebaseFirestore db;
  final FirebaseAuth auth;

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please Sign In.'));

    final stream = db.collection('vacancies').where('employerId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No Vacancies Yet.'));
        final docs = snap.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final d = docs[i];
            final data = d.data();
            final title = (data['title'] as String?) ?? 'Vacancy';
            final slots = (data['slots'] as num?)?.toInt() ?? 0;
            final rate = data['ratePerHour'];
            final updatedAt = data['updatedAt'] as Timestamp?;
            final updatedStr = updatedAt != null ? _formatDate(updatedAt.toDate()) : '';

            return Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: ListTile(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => VacancyDetailScreen(vacancyId: d.id, vacancyData: data))),
                title: Text(title),
                subtitle: Text('Slots: $slots • ${rate != null ? '\$${rate.toString()} /hr' : 'Rate N/A'}${updatedStr.isNotEmpty ? ' · $updatedStr' : ''}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () {
                        context.pushNamed('vacancy-edit', pathParameters: {'id': d.id});
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime dt) => DateFormat.yMMMd().add_jm().format(dt);
}

class _EmployerApplicationsSection extends StatelessWidget {
  const _EmployerApplicationsSection({required this.db, required this.auth, required this.appSvc});

  final FirebaseFirestore db;
  final FirebaseAuth auth;
  final ApplicationService appSvc;

  @override
  Widget build(BuildContext context) {
    final uid = auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please Sign In.'));

    final stream = db.collection('applications').where('employerId', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        // debug info to help trace missing-doc issues
        try {
          final count = snap.hasData ? snap.data!.docs.length : 0;
          debugPrint('EMP APPS SNAP: hasData=${snap.hasData} count=$count');
        } catch (_) {}

        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No Applications Yet.'));

        final docs = snap.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final doc = docs[i];
            final a = doc.data();
            final status = (a['status'] as String?) ?? 'sent';
            final createdAt = a['createdAt'] as Timestamp?;
            final createdStr = createdAt != null ? DateFormat.yMMMd().add_jm().format(createdAt.toDate()) : '';
            final workerName = (a['workerProfile'] is Map) ? (a['workerProfile'] as Map)['name'] as String? ?? (a['workerId'] as String? ?? 'Applicant') : (a['workerId'] as String? ?? 'Applicant');
            final vacancyId = a['vacancyId'] as String?;

            return Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                title: Text(workerName),
                subtitle: Text('Applied For: ${a['vacancyTitle'] ?? 'Vacancy'}\nStatus: $status • $createdStr'),
                isThreeLine: true,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Timeline',
                      icon: const Icon(Icons.timeline),
                      onPressed: () {
                        final timeline = (a['timeline'] as List<dynamic>?) ?? [];
                        showModalBottomSheet(
                          context: context,
                          builder: (c) => SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text('Application Timeline', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 8),
                                  if (timeline.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Text('No Timeline Entries Yet.')),
                                  if (timeline.isNotEmpty)
                                    Flexible(
                                      child: ListView.separated(
                                        shrinkWrap: true,
                                        itemCount: timeline.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1),
                                        itemBuilder: (context, idx) {
                                          final e = Map<String, dynamic>.from(timeline[idx] as Map);
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
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    IconButton(
                      tooltip: 'Open vacancy',
                      icon: const Icon(Icons.open_in_new),
                      onPressed: vacancyId == null
                          ? null
                          : () async {
                              final vacDoc = await db.collection('vacancies').doc(vacancyId).get();
                              final vacData = vacDoc.exists ? vacDoc.data() : null;
                              if (vacData != null) {
                                Navigator.of(context).push(MaterialPageRoute(builder: (c) => VacancyDetailScreen(vacancyId: vacancyId, vacancyData: vacData)));
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vacancy Not Found')));
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

