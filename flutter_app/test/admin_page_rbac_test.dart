import 'package:ebs_lite/features/admin/presentation/pages/admin_page.dart';
import 'package:ebs_lite/features/auth/controllers/auth_permissions_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child, {required List<String> permissions}) {
  return ProviderScope(
    overrides: [
      authPermissionsProvider.overrideWithValue(permissions),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('AdminPage shows Users tile with VIEW_USERS', (tester) async {
    await tester.pumpWidget(
      _wrap(const AdminPage(), permissions: const ['VIEW_USERS']),
    );

    expect(find.text('Users'), findsOneWidget);
    expect(find.text('Roles & Permissions'), findsNothing);
  });

  testWidgets('AdminPage shows Roles tile with VIEW_ROLES', (tester) async {
    await tester.pumpWidget(
      _wrap(const AdminPage(), permissions: const ['VIEW_ROLES']),
    );

    expect(find.text('Users'), findsNothing);
    expect(find.text('Roles & Permissions'), findsOneWidget);
  });
}
