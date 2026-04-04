import 'package:ebs_lite/features/customers/presentation/pages/customers_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Customers menu shows B2B Parties and hides Customer Care Hub',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CustomersPage()),
      ),
    );

    expect(find.text('B2B Parties'), findsOneWidget);
    expect(find.text('Customer Care Hub'), findsNothing);
  });

  testWidgets('Sales menu no longer shows B2B Parties', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: SalesPage()),
        ),
      ),
    );

    expect(find.text('B2B Invoices'), findsOneWidget);
    expect(find.text('B2B Parties'), findsNothing);
  });
}
