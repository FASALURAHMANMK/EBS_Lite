import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/outbox/outbox_item.dart';
import '../../../../core/outbox/outbox_notifier.dart';

class SyncHealthPage extends ConsumerStatefulWidget {
  const SyncHealthPage({super.key});

  @override
  ConsumerState<SyncHealthPage> createState() => _SyncHealthPageState();
}

class _SyncHealthPageState extends ConsumerState<SyncHealthPage> {
  late Future<List<OutboxItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(outboxNotifierProvider.notifier).listPending(limit: 200);
  }

  Future<void> _reload() async {
    setState(() {
      _future =
          ref.read(outboxNotifierProvider.notifier).listPending(limit: 200);
    });
    await _future;
  }

  Future<void> _exportDebugBundle(List<OutboxItem> items) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final outboxState = ref.read(outboxNotifierProvider);
      final payload = <String, dynamic>{
        'generated_at': DateTime.now().toUtc().toIso8601String(),
        'outbox': {
          'is_online': outboxState.isOnline,
          'queued_count': outboxState.queuedCount,
          'is_syncing': outboxState.isSyncing,
          'last_error': outboxState.lastError,
          'last_sync_at': outboxState.lastSyncAt?.toIso8601String(),
          'items': items
              .map((it) => {
                    'id': it.id,
                    'type': it.type,
                    'method': it.method,
                    'path': it.path,
                    'attempts': it.attempts,
                    'status': it.status,
                    'created_at_ms': it.createdAt,
                    'idempotency_key': it.idempotencyKey,
                    'last_error': it.lastError,
                    'query_params': it.queryParams,
                    'headers': it.headers,
                  })
              .toList(),
        },
      };

      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filename = 'ebs_sync_debug_$ts.json';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonEncode(payload), flush: true);

      await Share.shareXFiles(
        [XFile(file.path, name: filename, mimeType: 'application/json')],
        subject: 'EBS Lite sync debug bundle',
        text: 'Sync health debug bundle attached.',
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDiscard(OutboxItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Discard item?'),
        content: Text(
          'This will permanently remove the queued item.\n\n'
          '${item.method} ${item.path}\n'
          'type: ${item.type}\n'
          'attempts: ${item.attempts}\n'
          'status: ${item.status}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (item.id == null) return;
    await ref.read(outboxNotifierProvider.notifier).discardItem(item.id!);
    await _reload();
  }

  Future<void> _retryItem(OutboxItem item) async {
    if (item.id == null) return;
    await ref.read(outboxNotifierProvider.notifier).retryItem(item.id!);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outbox = ref.watch(outboxNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync health'),
        actions: [
          IconButton(
            tooltip: 'Retry now',
            onPressed: () async {
              await ref.read(outboxNotifierProvider.notifier).retryNow();
              if (context.mounted) await _reload();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<OutboxItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <OutboxItem>[];
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              outbox.isOnline
                                  ? Icons.wifi_rounded
                                  : Icons.wifi_off_rounded,
                              color: outbox.isOnline
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              outbox.isOnline ? 'Online' : 'Offline',
                              style: theme.textTheme.titleMedium,
                            ),
                            const Spacer(),
                            Text('Queued: ${outbox.queuedCount}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (outbox.isSyncing) const Text('Syncing...'),
                        if ((outbox.lastError ?? '').isNotEmpty)
                          Text(
                            'Last error: ${outbox.lastError}',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: items.isEmpty
                                  ? null
                                  : () => _exportDebugBundle(items),
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Export debug bundle'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _reload,
                              icon: const Icon(Icons.sync_rounded),
                              label: const Text('Refresh'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No queued or failed items.'),
                  )
                else
                  ...items.map((item) {
                    final created = DateTime.fromMillisecondsSinceEpoch(
                      item.createdAt,
                    ).toLocal();
                    return Card(
                      elevation: 0,
                      color: theme.colorScheme.surface,
                      child: ListTile(
                        title:
                            Text('${item.type} • ${item.method} ${item.path}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              'status: ${item.status} • attempts: ${item.attempts} • created: $created',
                            ),
                            if ((item.idempotencyKey ?? '').isNotEmpty)
                              Text('idempotency: ${item.idempotencyKey}'),
                            if ((item.lastError ?? '').isNotEmpty)
                              Text(
                                item.lastError!,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style:
                                    TextStyle(color: theme.colorScheme.error),
                              ),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            switch (v) {
                              case 'retry':
                                await _retryItem(item);
                                break;
                              case 'discard':
                                await _confirmDiscard(item);
                                break;
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'retry',
                              child: Text('Retry'),
                            ),
                            PopupMenuItem(
                              value: 'discard',
                              child: Text('Discard'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}
