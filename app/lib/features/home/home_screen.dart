import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eventify')),
      body: const PlaceholderView(
        icon: Icons.explore,
        title: 'Events near you',
        message: 'Upcoming events in Accra will appear here.',
      ),
    );
  }
}
