import 'package:flutter/material.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../customers/presentation/pages/customer_care_hub_page.dart';
import '../../../inventory/presentation/pages/inventory_operations_page.dart';
import '../../../workflow/presentation/pages/approvals_hub_page.dart';
import '../widgets/dashboard_sidebar.dart';
import 'settings_page.dart';

class HelpSupportPage extends StatelessWidget {
  const HelpSupportPage({super.key, this.fromMenu = false, this.onMenuSelect});

  final bool fromMenu;
  final void Function(BuildContext context, String label)? onMenuSelect;

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    return Scaffold(
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
        title: const Text('Help & Support'),
      ),
      drawer: fromMenu
          ? DashboardSidebar(
              onSelect: (label) => onMenuSelect?.call(context, label),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Operational help center',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Use these live pages to resolve the most common store and back-office issues without dead ends.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _HelpTile(
            icon: Icons.approval_rounded,
            title: 'Approvals and escalations',
            subtitle:
                'Review procurement, returns, and sensitive configuration requests.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ApprovalsHubPage()),
            ),
          ),
          _HelpTile(
            icon: Icons.inventory_2_rounded,
            title: 'Inventory operations',
            subtitle:
                'Find stock by barcode, inspect tracking details, and work the replenishment queue.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const InventoryOperationsPage()),
            ),
          ),
          _HelpTile(
            icon: Icons.support_agent_rounded,
            title: 'Customer care',
            subtitle:
                'Handle collections, loyalty, promotions, gift redemption, and warranty service.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CustomerCareHubPage()),
            ),
          ),
          _HelpTile(
            icon: Icons.settings_rounded,
            title: 'System settings',
            subtitle:
                'Review configurable behavior and submit sensitive changes for approval.',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpTile extends StatelessWidget {
  const _HelpTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
