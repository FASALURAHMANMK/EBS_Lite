// lib/dashboard/presentation/dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardHeader extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const DashboardHeader({
    super.key,
    this.isOnline = true,
    this.onToggleTheme,
    this.onNotifications,
    this.title = 'Dashboard',
  });

  /// Realtime/Sync status
  final bool isOnline;

  /// Callbacks
  final VoidCallback? onToggleTheme;
  final VoidCallback? onNotifications;
  final String title;

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
    final statusColor =
        widget.isOnline ? Colors.green : theme.colorScheme.error;
    final statusIcon =
        widget.isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded;

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
            message: widget.isOnline
                ? 'All changes are synced'
                : 'Offline — changes will sync later',
            child: Icon(statusIcon, color: statusColor),
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
          icon: const Icon(Icons.notifications_none_rounded),
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
