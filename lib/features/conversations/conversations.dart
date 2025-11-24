// Conversations UI: list + conversation detail with message sending.
// Messages are written to conversations/{convId}/messages/{msgId}
// Conversation doc fields used: participants: [uid,...], lastMessage, updatedAt, vacancyId?, applicationId?
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ConversationsListScreen extends StatelessWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Please sign in.'));

    final q = FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: q,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) return const Center(child: Text('No conversations yet.'));
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final d = docs[i];
              final data = d.data();
              final participants = (data['participants'] as List<dynamic>?)?.cast<String>() ?? [];
              final other = participants.where((p) => p != uid).isEmpty ? (uid) : participants.firstWhere((p) => p != uid);
              final lastMessage = (data['lastMessage'] as String?) ?? '';
              final subtitle = lastMessage;
              final title = (data['title'] as String?) ?? other;
              return ListTile(
                title: Text(title),
                subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (c) => ConversationScreen(convId: d.id))),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Simple new conversation flow: prompt for peer UID (or implement search)
          showDialog<String>(
            context: context,
            builder: (c) {
              final ctrl = TextEditingController();
              return AlertDialog(
                title: const Text('Start conversation'),
                content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Peer user id')),
                actions: [
                  TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.of(c).pop(ctrl.text.trim()), child: const Text('Start')),
                ],
              );
            },
          ).then((peerId) {
            if (peerId == null || peerId.isEmpty) return;
            Navigator.of(context).push(MaterialPageRoute(builder: (c) => ConversationScreen(peerId: peerId)));
          });
        },
        child: const Icon(Icons.create),
      ),
    );
  }
}

class ConversationScreen extends StatefulWidget {
  // Pass either convId (open existing) or peerId to start new conversation.
  final String? convId;
  final String? peerId;
  final String? relatedVacancyId;
  final String? relatedApplicationId;

  const ConversationScreen({super.key, this.convId, this.peerId, this.relatedVacancyId, this.relatedApplicationId});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  String? _convId;
  final _textCtrl = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _convId = widget.convId;
    if (_convId == null && widget.peerId != null) {
      _createConversationWithPeer(widget.peerId!);
    }
  }

  Future<void> _createConversationWithPeer(String peerId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    // lookup existing conversation between same participants
    final q = await _db
        .collection('conversations')
        .where('participants', arrayContains: uid)
        .get();
    for (final d in q.docs) {
      final parts = (d.data()['participants'] as List<dynamic>?)?.cast<String>() ?? [];
      if (parts.length == 2 && parts.contains(peerId)) {
        setState(() => _convId = d.id);
        return;
      }
    }
    final doc = await _db.collection('conversations').add({
      'participants': [uid, peerId],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'vacancyId': widget.relatedVacancyId,
      'applicationId': widget.relatedApplicationId,
    });
    setState(() => _convId = doc.id);
  }

  Future<void> _sendMessage() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || (_convId == null && widget.peerId == null)) return;
    if (_convId == null) {
      await _createConversationWithPeer(widget.peerId!);
      if (_convId == null) return;
    }
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    final msgRef = _db.collection('conversations').doc(_convId).collection('messages').doc();
    final conversationRef = _db.collection('conversations').doc(_convId);
    final convSnap = await conversationRef.get();
    final convData = convSnap.exists ? convSnap.data()! : {};
    final participants = (convData['participants'] as List<dynamic>?)?.cast<String>() ?? [];

    await _db.runTransaction((tx) async {
      tx.set(msgRef, {
        'from': uid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
        'recipients': participants.where((p) => p != uid).toList(),
        'relatedVacancyId': widget.relatedVacancyId,
        'relatedApplicationId': widget.relatedApplicationId,
      });
      tx.update(conversationRef, {
        'lastMessage': text,
        'lastSender': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    _textCtrl.clear();
    // scroll to bottom after a short delay so message appears
    await Future.delayed(const Duration(milliseconds: 250));
    if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Please sign in.')));

    if (_convId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conversation')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final msgsStream = _db
        .collection('conversations')
        .doc(_convId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots();

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: msgsStream,
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                return ListView.builder(
                  controller: _scroll,
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final m = docs[i].data();
                    final from = m['from'] as String?;
                    final text = m['text'] as String? ?? '';
                    final isMe = from == uid;

                    // Use theme colors for bubbles and text (brand / surfaceVariant)
                    final theme = Theme.of(context);
                    final bubbleColor = isMe
                        ? theme.colorScheme.primary
                        : (theme.colorScheme.surfaceVariant ?? theme.colorScheme.surface.withOpacity(0.9));
                    final textColor = isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: bubbleColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(text, style: TextStyle(color: textColor)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                    decoration: const InputDecoration(hintText: 'Write a message'),
                  ),
                ),
                IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send))
              ],
            ),
          ),
        ],
      ),
    );
  }
}
