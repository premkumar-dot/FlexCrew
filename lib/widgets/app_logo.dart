import 'package:flutter/material.dart';

/// Shows your uploaded white-backgroundless PNG/SVG.
/// Put the file at assets/logo/flexcrew_logo.png and ensure pubspec.yaml includes it.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.height = 120,
    this.showTagline = true,
  });

  final double height;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/logo/flexcrew_logo.png',
          height: height,
          fit: BoxFit.contain,
        ),
        if (showTagline) const SizedBox(height: 8),
        if (showTagline)
          const Text(
            'YOUR CREW, ON DEMAND',
            style: TextStyle(
              letterSpacing: 2,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

