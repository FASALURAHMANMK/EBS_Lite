import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../inventory/presentation/pages/product_transactions_page.dart';
import '../../../workflow/presentation/pages/workflow_requests_page.dart';
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
  Object? _error;
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
      setState(() => _error = e);
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

  Color _severityColor(BuildContext context, NotificationDto item) {
    switch (item.severity.toUpperCase()) {
      case 'CRITICAL':
        return Theme.of(context).colorScheme.error;
      case 'WARNING':
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.primary;
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

  Future<void> _openNotification(NotificationDto item) async {
    if (!item.isRead) {
      await _markRead([item.key]);
    }
    if (!mounted) return;

    if (item.approvalId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              WorkflowRequestDetailPage(approvalId: item.approvalId!),
        ),
      );
      return;
    }

    if (item.productId != null && item.type.toUpperCase() == 'LOW_STOCK') {
      final productName =
          item.title.replaceFirst(RegExp(r'^Low stock:\s*'), '');
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductTransactionsPage(
            productId: item.productId!,
            productName: productName.isEmpty ? 'Product' : productName,
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(item.title),
        content: Text(item.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final theme = Theme.of(context);

    final unread = _items.where((e) => !e.isRead).toList();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
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
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: AppErrorView(error: _error!, onRetry: _load),
              )
            else if (!_loading && _items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: Text('No notifications')),
              )
            else
              ..._items.map((n) {
                final severityColor = _severityColor(context, n);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: theme.colorScheme.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: severityColor.withValues(alpha: .12),
                        child: Icon(_iconForType(n.type), color: severityColor),
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
                          if ((n.badgeLabel ?? '').trim().isNotEmpty)
                            'State: ${n.badgeLabel!.trim()}',
                          if (_fmtTime(n.dueAt).isNotEmpty)
                            'Due: ${_fmtTime(n.dueAt)}',
                          if (_fmtTime(n.createdAt).isNotEmpty)
                            _fmtTime(n.createdAt),
                        ].join('\n'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _openNotification(n),
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
