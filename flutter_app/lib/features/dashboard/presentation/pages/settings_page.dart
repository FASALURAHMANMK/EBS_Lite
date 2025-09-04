import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/ui_prefs_notifier.dart';
import 'company_settings_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showQuick = ref.watch(quickActionVisibilityProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: const Text('Theme'),
            subtitle: const Text('Light / Dark'),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            value: showQuick,
            onChanged: (v) =>
                ref.read(quickActionVisibilityProvider.notifier).setVisible(v),
            title: const Text('Quick Action Button'),
            subtitle: const Text('Show floating quick actions'),
            secondary: const Icon(Icons.flash_on_rounded),
            tileColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.notifications_rounded),
            title: const Text('Notifications'),
            subtitle: const Text('Manage alerts and reminders'),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.business_rounded),
            title: const Text('Company Settings'),
            subtitle: const Text('Manage Company Settings'),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CompanySettingsPage()),
              );
            },
          ),
           const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.security_rounded),
            title: const Text('Security'),
            subtitle: const Text('Two-factor, sessions'),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
          ),
        ],
      ),
    );
  }
}
