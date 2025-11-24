import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginState();
}

class _LoginState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  String _role = 'worker';
  bool _loading = false;

  String _normalizeRole(String? r) {
    final rl = (r ?? 'worker').trim().toLowerCase();
    if (rl == 'employer') return 'employer';
    return 'worker';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _login() async {
    setState(() => _loading = true);

    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.isEmpty) {
      if (mounted) setState(() => _loading = false);
      _showSnack('Please provide both email and password.');
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: pw,
      );

      // Read persisted role if available, otherwise fall back to selected UI role
      final doc = await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).get();
      String persisted = doc.data()?['role'] as String? ?? '';
      persisted = _normalizeRole(persisted.isNotEmpty ? persisted : _role);

      // Ensure users/{uid}.role exists and is normalized (best-effort)
      try {
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'role': persisted,
        }, SetOptions(merge: true));
      } catch (_) {
        // ignore persistence error — still navigate using resolved role
      }

      if (!mounted) return;
      context.go(persisted == 'employer' ? '/employer' : '/worker');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack('Login failed: ${e.code}${e.message != null ? ' — ${e.message}' : ''}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    setState(() => _loading = true);

    final email = _email.text.trim();
    final pw = _pw.text;
    if (email.isEmpty || pw.isEmpty) {
      if (mounted) setState(() => _loading = false);
      _showSnack('Please provide both email and password.');
      return;
    }
    if (pw.length < 6) {
      if (mounted) setState(() => _loading = false);
      _showSnack('Password must be at least 6 characters.');
      return;
    }

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pw,
      );

      final normalized = _normalizeRole(_role);
      await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
        'email': email,
        'role': normalized,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      context.go(normalized == 'employer' ? '/employer' : '/worker');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      _showSnack('Register failed: ${e.code}${e.message != null ? ' — ${e.message}' : ''}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Register failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final scheme = Theme.of(c).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.asset('assets/branding/flexcrew-mark.svg', height: 40),
                  const SizedBox(width: 10),
                  Text('FlexCrew',
                      style: Theme.of(c).textTheme.headlineMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 8),
                Text('Find flexible work. Join the crew.', textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodyLarge),
                const SizedBox(height: 32),
                TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _pw, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
                const SizedBox(height: 12),
                DropdownButtonFormField(
                  value: _role,
                  items: const [
                    DropdownMenuItem(value: 'worker', child: Text('Worker')),
                    DropdownMenuItem(value: 'employer', child: Text('Employer')),
                  ],
                  onChanged: (v) => setState(() => _role = v as String? ?? 'worker'),
                ),
                const SizedBox(height: 18),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else
                  Column(
                    children: [
                      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _login, child: const Text('Sign in'))),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _register, child: const Text('Create account'))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
