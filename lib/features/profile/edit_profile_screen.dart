// Small wrapper so app_router can import EditProfileScreen as before.
import 'package:flutter/material.dart';
import 'worker_profile_edit_screen.dart';

class EditProfileScreen extends StatelessWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const WorkerProfileEditScreen();
}
