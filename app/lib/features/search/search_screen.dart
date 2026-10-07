import 'package:flutter/material.dart';

import '../../widgets/placeholder_view.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: const PlaceholderView(
        icon: Icons.search,
        title: 'Find events',
        message: 'Search by name, place, category or organizer.',
      ),
    );
  }
}
