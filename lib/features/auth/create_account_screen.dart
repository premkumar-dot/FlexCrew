import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key, this.prefillEmail, this.role});

  final String? prefillEmail;
  final String? role; // 'crew' or 'employer'

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  final TextEditingController _displayName = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty) {
      _email.text = widget.prefillEmail!;
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _displayName.dispose();
    super.dispose();
  }

  String _normalizeRole(String? r) {
    final rl = (r ?? 'crew').trim().toLowerCase();
    if (rl == 'employer') return 'employer';
    return 'worker'; // map crew -> worker and fallback
  }

  Future<void> _onCreatePressed() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final auth = FirebaseAuth.instance;
      final userCred = await auth.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final uid = userCred.user?.uid;
      if (uid != null) {
        final normalizedRole = _normalizeRole(widget.role);
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'email': _email.text.trim(),
          'displayName': _displayName.text.trim(),
          'role': normalizedRole,
          'createdAt': FieldValue.serverTimestamp(),
          'onboardingComplete': false,
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account created')));

      // Optionally navigate to onboarding based on selected role
      if (widget.role == 'employer') {
        // Use go_router to navigate (push) so named route handling works
        context.push('/employer/onboarding');
      } else {
        context.push('/onboarding');
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Failed to create account')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final role = widget.role ?? 'crew';

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _displayName,
                  decoration: const InputDecoration(labelText: 'Full name', border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter an email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirm,
                  decoration: const InputDecoration(labelText: 'Confirm password', border: OutlineInputBorder()),
                  obscureText: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirm your password';
                    if (v != _password.text) return 'Passwords do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white),
                    onPressed: _loading ? null : _onCreatePressed,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _loading ? const CircularProgressIndicator.adaptive() : const Text('Create account')),
                  ),
                ),
                const SizedBox(height: 8),

                // Onboarding link appears only on Create Account screen
                TextButton(
                  onPressed: () {
                    if (role == 'employer') {
                      context.push('/employer/onboarding');
                    } else {
                      context.push('/onboarding');
                    }
                  },
                  child: Text(
                    role == 'employer' ? 'Start employer onboarding' : 'Start crew onboarding',
                    style: TextStyle(color: primary),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
