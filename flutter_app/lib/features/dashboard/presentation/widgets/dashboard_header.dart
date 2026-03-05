import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardHeader extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const DashboardHeader({
    super.key,
    this.isOnline = true,
    this.isChecking = false,
    this.queuedCount = 0,
    this.isSyncing = false,
    this.onRetry,
    this.onToggleTheme,
    this.onNotifications,
    this.unreadNotificationsCount = 0,
    this.title = 'Dashboard',
  });

  /// Realtime/Sync status
  final bool isOnline;
  final bool isChecking;
  final int queuedCount;
  final bool isSyncing;
  final VoidCallback? onRetry;

  /// Callbacks
  final VoidCallback? onToggleTheme;
  final VoidCallback? onNotifications;
  final String title;

  final int unreadNotificationsCount;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  ConsumerState<DashboardHeader> createState() => _DashboardHeaderState();
}

class _DashboardHeaderState extends ConsumerState<DashboardHeader> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = widget.isChecking
        ? theme.colorScheme.onSurfaceVariant
        : (widget.isOnline ? Colors.green : theme.colorScheme.error);
    final statusIcon = widget.isChecking
        ? Icons.cloud_sync_rounded
        : (widget.isOnline
            ? Icons.cloud_done_rounded
            : Icons.cloud_off_rounded);

    return AppBar(
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: true,
      title: Text(widget.title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      actions: [
        // Online/Sync status chip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Tooltip(
            message: widget.isChecking
                ? 'Checking connection…'
                : (widget.isOnline
                    ? 'All changes are synced'
                    : 'Offline — changes will sync later'),
            child: Icon(statusIcon, color: statusColor),
          ),
        ),
        if (widget.queuedCount > 0 || widget.isSyncing)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: widget.onRetry,
              borderRadius: BorderRadius.circular(16),
              child: Tooltip(
                message: widget.isSyncing
                    ? 'Syncing queued changes'
                    : '${widget.queuedCount} queued • Tap to retry',
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      widget.isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        widget.isSyncing
                            ? 'Syncing...'
                            : 'Queued ${widget.queuedCount}',
                        style: theme.textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        // Theme toggle
        IconButton(
          tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
          icon:
              Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded),
          onPressed: widget.onToggleTheme,
        ),
        // Notifications
        IconButton(
          tooltip: 'Notifications',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.notifications_none_rounded),
              if (widget.unreadNotificationsCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      widget.unreadNotificationsCount > 99
                          ? '99+'
                          : widget.unreadNotificationsCount.toString(),
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.colorScheme.onError),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          onPressed: widget.onNotifications,
        ),
        const SizedBox(width: 4),
      ],
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, thickness: 1),
      ),
    );
  }
}
