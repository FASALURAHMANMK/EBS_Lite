// lib/dashboard/presentation/dashboard_sidebar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/controllers/auth_notifier.dart';
import '../../controllers/location_notifier.dart';
import '../../data/models.dart';

class DashboardSidebar extends ConsumerStatefulWidget {
  const DashboardSidebar({super.key, this.onSelect});

  final ValueChanged<String>? onSelect;

  @override
  ConsumerState<DashboardSidebar> createState() => _DashboardSidebarState();
}

class _DashboardSidebarState extends ConsumerState<DashboardSidebar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final locationState = ref.watch(locationNotifierProvider);

    return Drawer(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Brand header
            Container(
              alignment: Alignment.bottomCenter,
              height: 140, // custom height
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            authState.company?.name ?? '',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (locationState.locations.isNotEmpty)
                          Flexible(
                            child: DropdownButton<Location>(
                              isExpanded: true,
                              value: locationState.selected,
                              dropdownColor:
                                  theme.colorScheme.primaryContainer,
                              iconEnabledColor: Colors.white,
                              items: locationState.locations
                                  .map(
                                    (l) => DropdownMenuItem<Location>(
                                      value: l,
                                      child: Text(
                                        l.name,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (loc) {
                                if (loc != null) {
                                  ref
                                      .read(locationNotifierProvider.notifier)
                                      .select(loc);
                                }
                              },
                            ),
                          ),
                      ],
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
        widget.onSelect?.call(label);
      },
    );
  }
}
