import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';
import 'company_settings_page.dart';
import 'dashboard_customization_page.dart';
import 'inventory_settings_page.dart';
import 'invoice_settings_page.dart';
import 'printer_profiles_page.dart';
import 'security_settings_page.dart';
import 'theme_settings_page.dart';
import 'package:ebs_lite/features/notifications/presentation/pages/notifications_page.dart';
import 'package:ebs_lite/features/admin/presentation/pages/admin_page.dart';
import 'package:ebs_lite/features/auth/controllers/auth_permissions_provider.dart';
import 'package:ebs_lite/features/bulk_io/presentation/pages/import_export_page.dart';
import '../widgets/dashboard_sidebar.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({
    super.key,
    this.fromMenu = false,
    this.onMenuSelect,
  });

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final theme = Theme.of(context);
    final perms = ref.watch(authPermissionsProvider);
    final showAdmin =
        perms.contains('VIEW_USERS') || perms.contains('VIEW_ROLES');
    final scaffold = Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !fromMenu,
        leading: fromMenu
            ? Builder(
                builder: (context) => IconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              )
            : (isWide ? const DesktopSidebarToggleLeading() : null),
        leadingWidth: (!fromMenu && isWide) ? 104 : null,
        title: const Text('Settings'),
      ),
      drawer: fromMenu
          ? DashboardSidebar(
              onSelect: (label) => onMenuSelect?.call(context, label),
            )
          : null,
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
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ThemeSettingsPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_rounded),
            title: const Text('Dashboard'),
            subtitle: const Text('Shortcuts and quick action'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DashboardCustomizationPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.notifications_rounded),
            title: const Text('Notifications'),
            subtitle: const Text('Manage alerts and reminders'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.business_rounded),
            title: const Text('Company Settings'),
            subtitle: const Text('Company profile, taxes, payment methods'),
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
            leading: const Icon(Icons.inventory_2_rounded),
            title: const Text('Inventory Configuration'),
            subtitle: const Text(
                'View costing method and manage stock and profit guards'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const InventorySettingsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.receipt_long_rounded),
            title: const Text('Invoice Settings'),
            subtitle: const Text('Numbering + templates'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InvoiceSettingsPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.print_rounded),
            title: const Text('Printer profiles'),
            subtitle: const Text('Server-side printer configurations'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrinterProfilesPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.security_rounded),
            title: const Text('Security'),
            subtitle: const Text('Step-up approval, password, sessions'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SecuritySettingsPage()),
              );
            },
          ),
          const SizedBox(height: 12),
          if (showAdmin)
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_rounded),
              title: const Text('Admin'),
              subtitle: const Text('Users, roles, permissions'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              tileColor: theme.colorScheme.surface,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminPage()),
                );
              },
            ),
          if (showAdmin) const SizedBox(height: 12),
          ListTile(
            leading: const Icon(Icons.import_export_rounded),
            title: const Text('Import / Export'),
            subtitle: const Text('Customers, suppliers, inventory (Excel)'),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            tileColor: theme.colorScheme.surface,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportExportPage()),
              );
            },
          ),
        ],
      ),
    );

    if (!fromMenu) return scaffold;
    return PopScope(canPop: false, child: scaffold);
  }
}
