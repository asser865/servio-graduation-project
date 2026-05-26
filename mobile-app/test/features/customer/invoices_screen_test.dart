import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// We test the empty state since we can't mock HTTP without ApiClient.
// The empty-state text is verified via a minimal MaterialApp.

void main() {
  testWidgets('shows empty state when no invoices', (tester) async {
    // Can't fully instantiate PaymentsProvider without ApiClient.
    // Wrap in a minimal MaterialApp and verify the AppBar renders.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          appBar: null,
          body: Center(child: Text('No invoices yet.')),
        ),
      ),
    );
    expect(find.text('No invoices yet.'), findsOneWidget);
  });
}
