import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/onboarding'); // fallback route
            }
          },
        ),
        title: const Text('Terms & Conditions'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to FlexCrew',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '''
These Terms and Conditions (“Terms”) govern your use of the FlexCrew platform and services. By registering and using the application, you agree to abide by these Terms.

1. **Eligibility**
   Only registered users with verified profiles are allowed to perform tasks or post jobs on the platform.

2. **User Responsibilities**
   - Provide accurate information during onboarding.
   - Update your availability and contact details regularly.
   - Comply with all local labor and safety regulations during work.

3. **Payment and Wallet**
   - All payments and credits will appear in your FlexCrew Wallet.
   - Withdrawals or adjustments are subject to verification and approval.

4. **Confidentiality**
   All user data, job details, and related communications are confidential.

5. **Termination**
   FlexCrew reserves the right to suspend or terminate any account that violates these Terms or engages in fraudulent activity.

6. **Liability**
   FlexCrew acts only as a platform connecting employers and crew. It is not liable for disputes, accidents, or non-payment between users.

7. **Amendments**
   These Terms may be updated periodically. Continued use implies acceptance of any changes.

If you have questions, contact support@flexcrew.com.
                    ''',
                    style: TextStyle(fontSize: 15, height: 1.5),
                  ),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        context.go('/onboarding');
                      },
                      icon: const Icon(Icons.arrow_back),
                      label: const Text(
                        'Back to Onboarding',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

