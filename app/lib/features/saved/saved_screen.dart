import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Events')),
      body: const PlaceholderView(
        icon: Icons.bookmark_border,
        title: 'No saved events yet',
        message: 'Save an event to find it here later.',
      ),
    );
  }
}
