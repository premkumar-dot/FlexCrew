import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flexcrew/utils/nav_helpers.dart';

class LogoutButton extends StatelessWidget {
  const LogoutButton({super.key});
  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Log out',
      icon: const Icon(Icons.logout),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        await goLogout(context);
      },
    );
  }
}

