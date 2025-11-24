import 'dart:async';
import 'package:flutter/material.dart';

Future<void> runWithErrorUI(FutureOr<void> Function() body) async {
  await runZonedGuarded(() async {
    // Initialize bindings and set debug error UI inside the same zone
    WidgetsFlutterBinding.ensureInitialized();

    ErrorWidget.builder = (FlutterErrorDetails details) {
      return Material(
        color: Colors.white,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              details.exceptionAsString(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      );
    };

    await body();
  }, (error, stack) {
    // print to browser console so you get a JS error visible too
    // ignore: avoid_print
    print('Uncaught error: $error\n$stack');
  });
}
