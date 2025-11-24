import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.pop(), // returns to Onboarding without losing state
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('FlexCrew Terms & Conditions',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w700)),
                    SizedBox(height: 8),
                    Text('Last updated: 2025-10-30',
                        style: TextStyle(color: Colors.black54)),
                    SizedBox(height: 24),
                    Text('1. Introduction', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'Welcome to FlexCrew. By using our apps and services, you agree to these Terms. '
                      'Please read them carefully. If you do not agree, do not use the services.',
                    ),
                    SizedBox(height: 16),
                    Text('2. Eligibility', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'You must be legally eligible to work in your jurisdiction and provide accurate, complete, '
                      'and up-to-date information during registration and onboarding.',
                    ),
                    SizedBox(height: 16),
                    Text('3. Account Responsibilities', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'You are responsible for maintaining the confidentiality of your account credentials and for '
                      'all activities that occur under your account.',
                    ),
                    SizedBox(height: 16),
                    Text('4. Profiles, Vacancies & Engagements', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'FlexCrew connects Crew (workers) and Employers. We do not guarantee job availability or outcomes. '
                      'Engagement terms, payments, and compliance obligations are between the parties.',
                    ),
                    SizedBox(height: 16),
                    Text('5. Payments & Wallet', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'If a wallet is provided, you authorize us and our payment partners to process deposits and withdrawals. '
                      'Fees, limits, and timings may apply.',
                    ),
                    SizedBox(height: 16),
                    Text('6. Acceptable Use', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'Do not misuse the platform. Prohibited activities include fraud, harassment, unlawful conduct, '
                      'and attempts to disrupt service operation.',
                    ),
                    SizedBox(height: 16),
                    Text('7. Content & Privacy', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'You grant us a limited license to use submitted content to operate the services. '
                      'We process personal data per our Privacy Policy.',
                    ),
                    SizedBox(height: 16),
                    Text('8. Disclaimers & Liability', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'Services are provided “as is” without warranties. To the extent permitted by law, '
                      'we disclaim liability for indirect or consequential losses.',
                    ),
                    SizedBox(height: 16),
                    Text('9. Termination', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'We may suspend or terminate access for violations of these Terms or applicable law.',
                    ),
                    SizedBox(height: 16),
                    Text('10. Changes to Terms', style: _h),
                    SizedBox(height: 8),
                    Text(
                      'We may update these Terms. Continued use after changes indicates acceptance.',
                    ),
                    SizedBox(height: 24),
                    Divider(),
                    SizedBox(height: 12),
                    Text(
                      'For questions about these Terms, contact support@flexcrew.example (placeholder).',
                      style: TextStyle(color: Colors.black87),
                    ),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _h = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);

