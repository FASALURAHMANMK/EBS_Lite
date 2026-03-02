import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../controllers/ui_prefs_notifier.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import 'company_settings_page.dart';
import 'sync_health_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: 'unknown');
  static const String buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: 'unknown');

  Future<void> _generateSupportBundle(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final outboxState = ref.read(outboxNotifierProvider);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Generating support bundle...')),
          ],
        ),
      ),
    );

    try {
      final failed =
          await ref.read(outboxNotifierProvider.notifier).listFailed(limit: 50);

      final payload = <String, dynamic>{
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'app': {
          'version': appVersion,
          'build_number': buildNumber,
          'platform': Platform.operatingSystem,
          'platform_version': Platform.operatingSystemVersion,
        },
        'outbox': {
          'is_online': outboxState.isOnline,
          'queued_count': outboxState.queuedCount,
          'is_syncing': outboxState.isSyncing,
          'last_error': outboxState.lastError,
          'last_sync_at': outboxState.lastSyncAt?.toIso8601String(),
          'failed_items': failed
              .map((it) => {
                    'id': it.id,
                    'type': it.type,
                    'method': it.method,
                    'path': it.path,
                    'attempts': it.attempts,
                    'status': it.status,
                    'created_at_ms': it.createdAt,
                    'last_error': it.lastError,
                  })
              .toList(),
        },
      };

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'ebs_support_bundle_$ts.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonEncode(payload), flush: true);

      if (context.mounted) {
        Navigator.of(context).pop();
      }

      await Share.shareXFiles(
        [XFile(file.path, name: filename, mimeType: 'application/json')],
        subject: 'EBS Lite support bundle',
        text: 'Support bundle attached.',
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showQuick = ref.watch(quickActionVisibilityProvider);
    final outbox = ref.watch(outboxNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.palette_rounded),
            title: const Text('Theme'),
            subtitle: const Text('Light / Dark'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.notifications_rounded),
            title: const Text('Notifications'),
            subtitle: const Text('Manage alerts and reminders'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.business_rounded),
            title: const Text('Company Settings'),
            subtitle: const Text('Manage Company Settings'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Sync health'),
            subtitle: Text(
              'Queued/failed items (queued: ${outbox.queuedCount})',
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SyncHealthPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Generate support bundle'),
            subtitle: Text(
              'Includes app/platform + outbox failures (queued: ${outbox.queuedCount})',
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () => _generateSupportBundle(context, ref),
          ),
        ],
      ),
    );
  }
}
