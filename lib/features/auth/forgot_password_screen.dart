import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtl = TextEditingController();
  bool _loading = false;

  Future<void> _sendReset() async {
    final email = _emailCtl.text.trim().toLowerCase();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter your email')));
      return;
    }

    setState(() => _loading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('requestPasswordReset');
      // Call the server-side function. We don't show function result to user to avoid account enumeration.
      await callable.call(<String, dynamic>{'email': email});
    } catch (e) {
      // Log locally (optional) and continue to show the same generic message.
      // print('requestPasswordReset error: $e');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        // Generic message regardless of whether the email exists.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('If an account exists for this email you will receive a password reset link'),
        ));
      }
    }
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot password')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextFormField(
              controller: _emailCtl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _sendReset,
              child: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send reset'),
            ),
          ],
        ),
      ),
    );
  }
}
