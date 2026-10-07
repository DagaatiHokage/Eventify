import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const PlaceholderView(
        icon: Icons.person_outline,
        title: 'Your profile',
        message: 'Sign in to manage your city, interests and notifications.',
      ),
    );
  }
}
