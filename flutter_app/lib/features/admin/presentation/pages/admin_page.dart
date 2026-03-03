import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/controllers/auth_permissions_provider.dart';
import 'roles_admin_page.dart';
import 'users_admin_page.dart';

class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final perms = ref.watch(authPermissionsProvider);

    bool has(String p) => perms.contains(p);

    final canUsers = has('VIEW_USERS');
    final canRoles = has('VIEW_ROLES');

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (canUsers)
            ListTile(
              leading: const Icon(Icons.people_rounded),
              title: const Text('Users'),
              subtitle: const Text('Create, update, lock/disable'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: theme.colorScheme.surface,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UsersAdminPage()),
                );
              },
            ),
          if (canUsers) const SizedBox(height: 12),
          if (canRoles)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: const Text('Roles & Permissions'),
              subtitle: const Text('Manage roles and role permissions'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: theme.colorScheme.surface,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RolesAdminPage()),
                );
              },
            ),
          if (!canUsers && !canRoles)
            Card(
              elevation: 0,
              color: theme.colorScheme.surface,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You do not have permission to access admin features.',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
