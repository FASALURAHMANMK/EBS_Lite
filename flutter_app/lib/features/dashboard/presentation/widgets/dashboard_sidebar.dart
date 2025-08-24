// lib/dashboard/presentation/dashboard_sidebar.dart
import 'package:flutter/material.dart';

class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({super.key, this.onSelect});

  final ValueChanged<String>? onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Brand header
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor:
                        theme.colorScheme.onPrimary.withOpacity(0.1),
                    child: const Icon(Icons.business,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Company Name',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Menu items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(context, Icons.dashboard_rounded, 'Dashboard'),
                  _item(context, Icons.point_of_sale_rounded, 'Sales'),
                  _item(context, Icons.people_alt_rounded, 'Customers'),
                  _item(context, Icons.shopping_cart_rounded, 'Purchases'),
                  _item(context, Icons.inventory_2_rounded, 'Inventory'),
                  _item(context, Icons.account_balance_wallet_rounded,
                      'Accounting'),
                  _item(context, Icons.bar_chart_rounded, 'Reports'),
                  _item(context, Icons.group_rounded, 'HR'),
                  const Divider(height: 24),
                  _item(context, Icons.settings_rounded, 'Settings'),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'v1.0.0',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
      ),
      horizontalTitleGap: 12,
      onTap: () {
        Navigator.pop(context);
        onSelect?.call(label);
      },
    );
  }
}
