// lib/dashboard/presentation/dashboard_header.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardHeader extends ConsumerStatefulWidget
    implements PreferredSizeWidget {
  const DashboardHeader({
    super.key,
    this.isOnline = true,
    this.onToggleTheme,
    this.onHelp,
    this.onLogout,
  });

  /// Realtime/Sync status
  final bool isOnline;

  /// Callbacks
  final VoidCallback? onToggleTheme;
  final VoidCallback? onHelp;
  final VoidCallback? onLogout;

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
      title: const Text('Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600)),
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
        // Profile / Logout overflow
        PopupMenuButton<_HeaderMenu>(
          tooltip: 'Account',
          icon: const Icon(Icons.account_circle_rounded),
          onSelected: (v) {
            if (v == _HeaderMenu.logout) {
              widget.onLogout?.call();
            } else if (v == _HeaderMenu.help) {
              widget.onHelp?.call();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: _HeaderMenu.profile,
              child: ListTile(
                leading: Icon(Icons.person_rounded),
                title: Text('Profile'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: _HeaderMenu.help,
              child: ListTile(
                leading: Icon(Icons.help_outline_rounded),
                title: Text('Help & support'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: _HeaderMenu.logout,
              child: ListTile(
                leading: Icon(Icons.logout_rounded),
                title: Text('Logout'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
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

enum _HeaderMenu { profile, help, logout }
