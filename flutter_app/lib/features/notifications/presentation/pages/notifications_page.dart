import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../dashboard/presentation/pages/sync_health_page.dart';
import '../../controllers/notifications_providers.dart';
import '../../data/models.dart';
import '../../data/notifications_repository.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<NotificationDto> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(notificationsRepositoryProvider);
      final list = await repo.listNotifications();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(List<String> keys) async {
    try {
      await ref.read(notificationsRepositoryProvider).markRead(keys);
      ref.invalidate(notificationsUnreadCountProvider);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    }
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'LOW_STOCK':
        return Icons.inventory_2_rounded;
      case 'APPROVAL_PENDING':
        return Icons.rule_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _fmtTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outbox = ref.watch(outboxNotifierProvider);

    final unread = _items.where((e) => !e.isRead).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (unread.isNotEmpty)
            IconButton(
              tooltip: 'Mark all read',
              onPressed: () => _markRead(unread.map((e) => e.key).toList()),
              icon: const Icon(Icons.done_all_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 0,
              child: ListTile(
                leading: Icon(
                  outbox.isOnline
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded,
                  color:
                      outbox.isOnline ? Colors.green : theme.colorScheme.error,
                ),
                title: Text(outbox.isOnline ? 'Online' : 'Offline'),
                subtitle: Text(
                  outbox.queuedCount == 0
                      ? 'No queued items'
                      : '${outbox.queuedCount} queued/failed items',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncHealthPage()),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Alerts', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!),
              )
            else if (!_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No notifications')),
              )
            else
              ..._items.map((n) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: .12),
                        child: Icon(_iconForType(n.type),
                            color: theme.colorScheme.primary),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (!n.isRead)
                            Container(
                              height: 8,
                              width: 8,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        [
                          n.body,
                          if (_fmtTime(n.createdAt).isNotEmpty)
                            _fmtTime(n.createdAt),
                        ].join('\n'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        if (!n.isRead) await _markRead([n.key]);
                        if (!context.mounted) return;
                        await showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text(n.title),
                            content: Text(n.body),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
