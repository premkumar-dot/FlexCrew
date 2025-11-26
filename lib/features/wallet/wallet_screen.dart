import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flexcrew/widgets/user_avatar_button.dart';
import 'package:flexcrew/widgets/notification_bell.dart';

/// Compatibility wrapper used by the router.
/// Routes reference `WalletScreen(role: 'crew'|'employer')` — provide that API
/// while reusing the existing WorkerWalletScreen implementation.
class WalletScreen extends StatelessWidget {
  final String role;
  const WalletScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    // The underlying implementation ignores the role param and reads the role
    // from the wallet document. If you want the route-provided role to drive
    // behavior, forward it into the implementation later.
    return const WorkerWalletScreen();
  }
}

class WorkerWalletScreen extends StatefulWidget {
  const WorkerWalletScreen({super.key});

  @override
  State<WorkerWalletScreen> createState() => _WorkerWalletScreenState();
}

class _WorkerWalletScreenState extends State<WorkerWalletScreen> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final TextEditingController _amountCtrl = TextEditingController();

  String get _uid => _auth.currentUser?.uid ?? '';

  Future<void> _requestWithdraw(BuildContext ctx, double amount) async {
    if (_uid.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Not signed in')));
      return;
    }
    final doc = await _firestore.collection('payoutRequests').add({
      'uid': _uid,
      'amount': amount,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Withdraw requested (${doc.id})')));
  }

  Future<void> _showWithdrawDialog(BuildContext ctx, double maxAmount) async {
    _amountCtrl.text = maxAmount > 0 ? maxAmount.toStringAsFixed(2) : '';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (dCtx) => AlertDialog(
        title: const Text('Request withdrawal'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(prefixText: '\$ ', hintText: 'Amount'),
            validator: (v) {
              final txt = v?.trim() ?? '';
              if (txt.isEmpty) return 'Enter amount';
              final val = double.tryParse(txt);
              if (val == null) return 'Invalid number';
              if (val <= 0) return 'Must be greater than 0';
              if (val > maxAmount) return 'Cannot exceed balance';
              return null;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                final amt = double.parse(_amountCtrl.text.trim());
                Navigator.of(dCtx).pop();
                _requestWithdraw(ctx, amt);
              }
            },
            child: const Text('Request'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Widget _buildTransactionsList(String uid) {
    final txsRef = _firestore.collection('wallets').doc(uid).collection('transactions').orderBy('createdAt', descending: true);
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: txsRef.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snap.hasData || snap.data!.docs.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Text('No transactions'));
        final docs = snap.data!.docs;
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data = docs[i].data();
            final type = data['type']?.toString() ?? 'tx';
            final amount = (data['amount'] is num) ? (data['amount'] as num).toDouble() : 0.0;
            final created = (data['createdAt'] is Timestamp) ? (data['createdAt'] as Timestamp).toDate() : null;
            final status = data['status']?.toString() ?? '';

            final statusTooltip = status == 'pending'
                ? 'Pending: awaiting payment provider or server confirmation. Balance unchanged until status becomes "paid".'
                : 'Transaction status: $status';

            final trailingWidget = status.isNotEmpty
                ? Tooltip(
                    message: statusTooltip,
                    child: Text(status, style: const TextStyle(fontSize: 12)),
                  )
                : null;

            return ListTile(
              leading: Icon(type == 'credit' || type == 'deposit' ? Icons.arrow_downward : Icons.arrow_upward, color: type == 'credit' ? Colors.green : Colors.orange),
              title: Text('${type[0].toUpperCase()}${type.substring(1)} — \$${amount.toStringAsFixed(2)}'),
              subtitle: created != null ? Text('${created.toLocal()}') : null,
              trailing: trailingWidget,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Wallet'),
          backgroundColor: primary,
          toolbarHeight: 72,
          actions: const [NotificationBell(), UserAvatarButton()],
        ),
        body: const Center(child: Text('Not signed in')),
      );
    }

    final walletRef = _firestore.collection('wallets').doc(_uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: primary,
        toolbarHeight: 72,
        actions: const [NotificationBell(), UserAvatarButton()],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await walletRef.get();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: walletRef.snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: MediaQuery.of(context).size.height - kToolbarHeight - 48,
                  child: const Center(child: CircularProgressIndicator()),
                );
              }

              final data = snap.data?.data() ?? {};
              final balance = (data['balance'] is num) ? (data['balance'] as num).toDouble() : 0.0;
              final role = data['role']?.toString() ?? 'crew';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Role: $role', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Balance: \$${balance.toStringAsFixed(2)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dCtx) {
                              _amountCtrl.text = '';
                              final formKey = GlobalKey<FormState>();
                              return AlertDialog(
                                title: const Text('Top up wallet (demo)'),
                                content: Form(
                                  key: formKey,
                                  child: TextFormField(
                                    controller: _amountCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(prefixText: '\$ ', hintText: 'Amount'),
                                    validator: (v) {
                                      final t = v?.trim() ?? '';
                                      if (t.isEmpty) return 'Enter amount';
                                      return double.tryParse(t) == null ? 'Invalid' : null;
                                    },
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.of(dCtx).pop(), child: const Text('Cancel')),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (formKey.currentState?.validate() ?? false) {
                                        final amt = double.parse(_amountCtrl.text.trim());
                                        await walletRef.collection('transactions').add({
                                          'type': 'deposit',
                                          'amount': amt,
                                          'status': 'pending',
                                          'createdAt': FieldValue.serverTimestamp(),
                                        });
                                        Navigator.of(dCtx).pop();
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up recorded (pending)')));
                                      }
                                    },
                                    child: const Text('Add'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Top up'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: balance <= 0 ? null : () => _showWithdrawDialog(context, balance),
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Withdraw'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _buildTransactionsList(_uid),
                  const SizedBox(height: 40),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
