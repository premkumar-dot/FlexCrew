import 'dart:async';
import 'package:flutter/material.dart';

/// In-app splash overlay that mimics the web shell splash.
/// - Shows a white background with centered logo at `assets/branding/flexcrew-logo.png`
/// - Automatically fades out after the first frame + short delay.
/// - Integrate by placing `WebStyleSplash()` above your `MaterialApp` in a Stack.
class WebStyleSplash extends StatefulWidget {
  const WebStyleSplash({super.key, this.duration = const Duration(milliseconds: 600)});

  /// Time to keep the splash visible after first frame.
  final Duration duration;

  @override
  State<WebStyleSplash> createState() => _WebStyleSplashState();
}

class _WebStyleSplashState extends State<WebStyleSplash> with SingleTickerProviderStateMixin {
  bool _visible = true;
  late final AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    // Hide splash after Flutter first frame + configured duration.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(widget.duration, () {
        if (!mounted) return;
        _fadeController.forward();
        // remove widget after fade completes
        Timer(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _visible = false);
        });
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0).animate(_fadeController),
      child: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Image.asset(
          'assets/branding/flexcrew-logo.png',
          width: 400,
          height: null,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
