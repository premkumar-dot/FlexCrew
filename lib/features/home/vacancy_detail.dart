import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/user_avatar_button.dart';

class VacancyDetailScreen extends StatefulWidget {
  final String vacancyId;
  final Map<String, dynamic> vacancyData;

  const VacancyDetailScreen({super.key, required this.vacancyId, required this.vacancyData});

  @override
  State<VacancyDetailScreen> createState() => _VacancyDetailScreenState();
}

class _VacancyDetailScreenState extends State<VacancyDetailScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  static final _dateFmt = DateFormat.yMMMd();
  static final _dateTimeFmt = DateFormat.yMMMd().add_jm();

  Future<void> _apply() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final vacancyId = widget.vacancyId;
    final employerId = widget.vacancyData['employerId'] as String?;

    // Validate vacancy status/slots/deadline before allowing apply
    final statusRaw = (widget.vacancyData['status'] as String?) ?? 'open';
    final status = statusRaw.trim().toLowerCase();
    final slotsRaw = widget.vacancyData['slots'];
    int slots = 0;
    if (slotsRaw is num) slots = slotsRaw.toInt();
    else if (slotsRaw is String) slots = int.tryParse(slotsRaw) ?? 0;
    final deadline = (widget.vacancyData['applicationDeadline'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    if (status != 'open' || slots <= 0 || (deadline != null && deadline.isBefore(now))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This vacancy is no longer accepting applications.')));
      return;
    }

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Apply now'),
        content: const Text('Apply using your profile and resume?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(c).pop(true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) return;

    final id = '${uid}_$vacancyId';
    final ref = _db.collection('applications').doc(id);

    try {
      // Prevent duplicate application by checking existing doc
      final existing = await ref.get();
      if (existing.exists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You have already applied.')));
        Navigator.of(context).pop();
        return;
      }

      await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (snap.exists) {
          throw FirebaseException(plugin: 'app', code: 'already-exists', message: 'Application already exists.');
        }
        final userSnap = await _db.collection('users').doc(uid).get();
        final userData = userSnap.exists ? (userSnap.data() ?? {}) : {};
        final profile = userData['profile'] ?? userData;
        tx.set(ref, {
          'vacancyId': vacancyId,
          'workerId': uid,
          'employerId': employerId,
          'status': 'sent',
          'workerProfile': profile,
          'resume': userData['resume'] ?? null,
          'timeline': [
            {
              'status': 'sent',
              'by': uid,
              'note': 'Application sent',
              'ts': FieldValue.serverTimestamp(),
            }
          ],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application sent')));
      Navigator.of(context).pop();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to apply')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to apply')));
    }
  }

  Widget _mapSnippet(Map<String, dynamic> data) {
    final lat = data['locationLat'];
    final lng = data['locationLng'];
    if (lat is num && lng is num) {
      final url =
          'https://maps.googleapis.com/maps/api/staticmap?center=$lat,$lng&zoom=14&size=600x200&markers=color:red%7C$lat,$lng';
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(url, height: 160, width: double.infinity, fit: BoxFit.cover),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  // Look up employer across common collections and field names.
  Future<Map<String, String?>> _loadEmployer(String? employerId) async {
    if (employerId == null || employerId.isEmpty) return {'name': null, 'avatar': null, 'bio': null};

    Map<String, String?> result = {'name': null, 'avatar': null, 'bio': null};

    // Helper to extract common fields
    void _extract(Map<String, dynamic>? d) {
      if (d == null) return;
      result['name'] ??= (d['name'] ?? d['displayName'] ?? d['fullName'] ?? d['companyName']) as String?;
      result['avatar'] ??= (d['avatarUrl'] ??
          d['photoUrl'] ??
          d['logoUrl'] ??
          d['imageUrl'] ??
          d['photo'] ??
          d['logo']) as String?;
      result['bio'] ??= (d['bio'] ?? d['description'] ?? d['about']) as String?;
    }

    final usersDoc = await _db.collection('users').doc(employerId).get();
    _extract(usersDoc.data());

    if (result['avatar'] == null || result['name'] == null) {
      final employersDoc = await _db.collection('employers').doc(employerId).get();
      _extract(employersDoc.data());
    }

    if (result['avatar'] == null || result['name'] == null) {
      final profilesDoc = await _db.collection('profiles').doc(employerId).get();
      _extract(profilesDoc.data());
    }

    return result;
  }

  void _showEmployerModal(BuildContext context, Map<String, String?> employer) {
    showModalBottomSheet(
      context: context,
      builder: (c) {
        final theme = Theme.of(c);
        final name = employer['name'] ?? 'Employer';
        final avatar = employer['avatar'];
        final bio = employer['bio'] ?? '';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: avatar != null && avatar.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(avatar, fit: BoxFit.contain, errorBuilder: (c, e, st) => Container(color: theme.colorScheme.surfaceVariant)))
                        : CircleAvatar(radius: 32, child: Text(name.characters.first.toUpperCase())),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(name, style: theme.textTheme.titleMedium), if (bio.isNotEmpty) Text(bio, style: theme.textTheme.bodySmall)])),
                ]),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Close'))]),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.vacancyData;
    final theme = Theme.of(context);
    final title = (data['title'] as String?) ?? 'Vacancy';
    final description = (data['description'] as String?) ?? '';
    final employerNameField = (data['employerName'] as String?) ?? (data['employer'] as String?);
    final employerAvatarField = (data['employerAvatarUrl'] as String?) ?? (data['employerAvatar'] as String?);
    final employerId = data['employerId'] as String?;
    final startAt = data['startAt'] as Timestamp?;
    final endAt = data['endAt'] as Timestamp?;
    final deadline = (data['applicationDeadline'] as Timestamp?)?.toDate();
    final rate = data['ratePerHour'];
    final slots = (data['slots'] as num?)?.toInt() ?? 0;
    final place = (data['location'] as String?) ?? 'Location not specified';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vacancy'),
        actions: const [UserAvatarButton()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _apply,
        label: const Text('Apply'),
        icon: const Icon(Icons.send),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          FutureBuilder<Map<String, String?>>(
            future: _loadEmployer(employerId),
            builder: (context, snap) {
              final employerName = (employerNameField != null && employerNameField.isNotEmpty) ? employerNameField : (snap.data?['name']);
              final employerAvatar = (employerAvatarField != null && employerAvatarField.isNotEmpty) ? employerAvatarField : (snap.data?['avatar']);

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary, // banner uses primary
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Fixed-size slot + FittedBox to preserve aspect ratio and scale logos correctly.
                    SizedBox(
                      width: 56,
                      height: 56,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: employerAvatar != null && employerAvatar.isNotEmpty
                            ? FittedBox(
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                child: Image.network(
                                  employerAvatar,
                                  // do not set explicit width/height here; FittedBox will scale the image
                                  errorBuilder: (c, e, st) {
                                    return Container(
                                      color: Colors.transparent,
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: Colors.white,
                                        child: Text(
                                          (employerName ?? title).characters.first.toUpperCase(),
                                          style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              )
                            : CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.white,
                                child: Text(
                                  (employerName ?? title).characters.first.toUpperCase(),
                                  style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700),
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(employerName ?? 'Employer', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimary.withOpacity(.9))),
                      ]),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          if (startAt != null || endAt != null)
            Text(
              startAt != null && endAt != null
                  ? '${_dateTimeFmt.format(startAt.toDate())} • ${_dateTimeFmt.format(endAt.toDate())}'
                  : (startAt != null ? _dateTimeFmt.format(startAt.toDate()) : _dateFmt.format(endAt!.toDate())),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 12),

          if (description.isNotEmpty) Text(description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),

          _mapSnippet(data),
          if ((data['locationLat'] is num && data['locationLng'] is num)) const SizedBox(height: 12),

          FutureBuilder<Map<String, String?>>(
            future: _loadEmployer(employerId),
            builder: (context, snap) {
              final employerName = (employerNameField != null && employerNameField.isNotEmpty) ? employerNameField : (snap.data?['name']);
              final employerAvatar = (employerAvatarField != null && employerAvatarField.isNotEmpty) ? employerAvatarField : (snap.data?['avatar']);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(place, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: employerAvatar != null && employerAvatar.isNotEmpty
                        ? Image.network(
                            employerAvatar,
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, st) => CircleAvatar(radius: 18, backgroundColor: theme.colorScheme.surfaceVariant, child: Text((employerName ?? title).characters.first.toUpperCase())),
                          )
                        : CircleAvatar(radius: 18, backgroundColor: theme.colorScheme.surfaceVariant, child: Text((employerName ?? title).characters.first.toUpperCase())),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    icon: const Icon(Icons.more_vert),
                    color: Theme.of(context).colorScheme.surface,
                    onSelected: (value) async {
                      if (value == 1) {
                        // always load latest employer data and show modal
                        final employer = await _loadEmployer(employerId);
                        if (context.mounted) _showEmployerModal(context, employer);
                      } else if (value == 2) {
                        if (context.mounted) {
                          showDialog(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: const Text('Report employer'),
                              content: const Text('Report this employer for inappropriate content?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(c).pop(true);
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reported')));
                                  },
                                  child: const Text('Report'),
                                ),
                              ],
                            ),
                          );
                        }
                      }
                    },
                    itemBuilder: (c) => [
                      PopupMenuItem(value: 1, child: Text('View employer', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                      PopupMenuItem(value: 2, child: Text('Report', style: TextStyle(color: Theme.of(context).colorScheme.onSurface))),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (rate != null)
                Chip(
                  label: Text('\$${rate.toString()} /hr'),
                ),
              Chip(label: Text('Slots: $slots')),
              if (deadline != null) Chip(label: Text('Apply by ${_dateFmt.format(deadline)}')),
            ],
          ),

          const SizedBox(height: 12),

          const Divider(),
          const SizedBox(height: 8),

          const Text('Similar jobs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),

          FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _similarJobs(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator()));
              final docs = snap.data ?? [];
              if (docs.isEmpty) return const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No similar jobs right now.'));
              return Column(
                children: docs.map((d) {
                  final map = d.data();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text((map['title'] as String?) ?? 'Vacancy'),
                    subtitle: Text((map['location'] as String?) ?? ''),
                    onTap: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (c) => VacancyDetailScreen(vacancyId: d.id, vacancyData: map),
                      ));
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _similarJobs() async {
    final tags = (widget.vacancyData['tags'] as List<dynamic>?)?.cast<String>() ?? [];
    if (tags.isEmpty) return [];
    final q = await _db
        .collection('vacancies')
        .where('status', isEqualTo: 'open')
        .where('tags', arrayContainsAny: tags.take(10).toList())
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    return q.docs.where((d) => d.id != widget.vacancyId).toList();
  }
}
