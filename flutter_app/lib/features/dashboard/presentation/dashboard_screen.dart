// lib/features/dashboard/presentation/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_notifier.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/quick_action_button.dart';
import '../../auth/controllers/auth_notifier.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  int _selectedIndex = 0;

  static const _destinations = <_NavItem>[
    _NavItem('Dashboard', Icons.dashboard_rounded),
    _NavItem('Sales', Icons.point_of_sale_rounded),
    _NavItem('Customers', Icons.people_alt_rounded),
    _NavItem('Purchases', Icons.shopping_cart_rounded),
    _NavItem('Inventory', Icons.inventory_2_rounded),
    _NavItem('Accounting', Icons.account_balance_wallet_rounded),
    _NavItem('Reports', Icons.bar_chart_rounded),
    _NavItem('HR', Icons.group_rounded),
    _NavItem('Settings', Icons.settings_rounded),
  ];

  void _onSelectByLabel(String label) {
    final idx = _destinations.indexWhere((e) => e.label == label);
    if (idx != -1) {
      setState(() => _selectedIndex = idx);
    }
  }

  void _onSelectByIndex(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final media = MediaQuery.of(context);
    final width = media.size.width;

    final authState = ref.watch(authNotifierProvider);
    final companyName = authState.company?.name ?? 'Company';

    final isWide = width >= 1000; // rail for desktop/tablet, drawer for phones
    final railExtended = width >= 1300;

    final theme = Theme.of(context);

    // (Optional) Swap the main content based on _selectedIndex.
    // For now, show DashboardContent for all to keep it runnable.
    final Widget content = const DashboardContent();

    return Scaffold(
      appBar: DashboardHeader(
        onToggleTheme: () => themeNotifier.toggle(),
        onLogout: () => Navigator.popUntil(context, (r) => r.isFirst),
        onHelp: () {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(
              content: Text('Help is on the way! (wire up your help center)'),
              behavior: SnackBarBehavior.floating,
            ));
        },
        companyName: companyName,
        isOnline: true,
      ),
      drawer: isWide
          ? null
          : DashboardSidebar(
              onSelect: (label) {
                Navigator.of(context).maybePop();
                _onSelectByLabel(label);
              },
            ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
              selectedIndex: _selectedIndex,
              extended: railExtended,
              groupAlignment: -0.9,
              minWidth: 72,
              leading: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Tooltip(
                  message: 'Toggle theme',
                  child: IconButton(
                    onPressed: () => themeNotifier.toggle(),
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                    ),
                  ),
                ),
              ),
              destinations: _destinations
                  .map(
                    (e) => NavigationRailDestination(
                      icon: Icon(e.icon,
                          color: theme.colorScheme.onSurfaceVariant),
                      selectedIcon:
                          Icon(e.icon, color: theme.colorScheme.primary),
                      label: Text(e.label),
                    ),
                  )
                  .toList(),
              onDestinationSelected: _onSelectByIndex,
            ),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: QuickActionButton(
        actions: const [
          QuickAction(icon: Icons.point_of_sale_rounded, label: 'Sale'),
          QuickAction(icon: Icons.shopping_cart_rounded, label: 'Purchase'),
          QuickAction(icon: Icons.payments_rounded, label: 'Collection'),
          QuickAction(icon: Icons.money_off_rounded, label: 'Expense'),
        ],
        onOpenChanged: (open) {
          // Example: dim app bar or log analytics here.
        },
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
