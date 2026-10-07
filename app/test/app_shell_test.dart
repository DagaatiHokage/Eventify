import 'package:eventify/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opens on Home and switches between the four tabs', (
    tester,
  ) async {
    await tester.pumpWidget(const EventifyApp());
    await tester.pumpAndSettle();

    expect(find.text('Events near you'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));

    await tester.tap(find.text('Search'));
    await tester.pumpAndSettle();
    expect(find.text('Find events'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('No saved events yet'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your profile'), findsOneWidget);

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('Events near you'), findsOneWidget);
  });
}
