// lib/features/dashboard/presentation/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme_notifier.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/quick_action_button.dart';
import '../controllers/dashboard_notifier.dart';
import '../controllers/ui_prefs_notifier.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/purchases_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/inventory_page.dart';
import 'package:ebs_lite/features/reports/presentation/pages/reports_page.dart';
import 'package:ebs_lite/features/customers/presentation/pages/customers_page.dart';
import 'package:ebs_lite/features/accounts/presentation/pages/accounting_page.dart';
import 'package:ebs_lite/features/hr/presentation/pages/hr_page.dart';
import 'pages/settings_page.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:ebs_lite/features/notifications/presentation/pages/notifications_page.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // Primary tabs for bottom navigation
  static const _primaryTabs = <_NavItem>[
    _NavItem('Dashboard', Icons.dashboard_rounded),
    _NavItem('Sales', Icons.point_of_sale_rounded),
    _NavItem('Purchases', Icons.shopping_cart_rounded),
    _NavItem('Inventory', Icons.inventory_2_rounded),
    _NavItem('Customers', Icons.people_alt_rounded),
  ];

  // Secondary items kept in sidebar/rail
  static const _secondaryItems = <_NavItem>[
    _NavItem('Reports', Icons.bar_chart_rounded),
    _NavItem('Accounting', Icons.account_balance_wallet_rounded),
    _NavItem('HR', Icons.group_rounded),
    _NavItem('Settings', Icons.settings_rounded),
  ];

  int _bottomIndex = 0;

  void _onSelectSecondaryByLabel(BuildContext context, String label) {
    // Push a sample page for secondary items to keep primary tabs persistent
    Widget page;
    switch (label) {
      case 'Reports':
        page = const ReportsPage();
        break;
      case 'Accounting':
        page = const AccountingPage();
        break;
      case 'HR':
        page = const HRPage();
        break;
      case 'Settings':
        page = const SettingsPage();
        break;
      default:
        page = Scaffold(
          appBar: AppBar(title: Text(label)),
          body: Center(child: Text('$label page')),
        );
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final media = MediaQuery.of(context);
    final width = media.size.width;

    final dashboardState = ref.watch(dashboardNotifierProvider);
    final quickCounts = dashboardState.quickActions;

    final isWide = width >= 1000; // rail for desktop/tablet, drawer for phones
    final railExtended = width >= 1300;

    final theme = Theme.of(context);

    // Primary tab pages (kept alive via IndexedStack)
    final pages = <Widget>[
      const DashboardContent(key: PageStorageKey('tab_dashboard')),
      const SalesPage(key: PageStorageKey('tab_sales')),
      const PurchasesPage(key: PageStorageKey('tab_purchases')),
      const InventoryPage(key: PageStorageKey('tab_inventory')),
      const CustomersPage(key: PageStorageKey('tab_customers')),
    ];

    final currentTitle = _primaryTabs[_bottomIndex].label;

    final showQuick = ref.watch(quickActionVisibilityProvider);

    return Scaffold(
      appBar: DashboardHeader(
        onToggleTheme: () => themeNotifier.toggle(),
        isOnline: true,
        title: currentTitle,
        onNotifications: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsPage()),
          );
        },
      ),
      drawer: isWide
          ? null
          : DashboardSidebar(
              onSelect: (label) {
                Navigator.of(context).maybePop();
                _onSelectSecondaryByLabel(context, label);
              },
            ),
      body: Row(
        children: [
          if (isWide)
            NavigationRail(
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
              destinations: _secondaryItems
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
              onDestinationSelected: (i) =>
                  _onSelectSecondaryByLabel(context, _secondaryItems[i].label),
              selectedIndex: null,
            ),
          Expanded(
            child: IndexedStack(
              index: _bottomIndex,
              children: pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomIndex,
        onDestinationSelected: (i) => setState(() => _bottomIndex = i),
        height: 68,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        // No chip/indicator around the icon
        indicatorColor: Colors.transparent,
        // Only show label for the selected tab
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: _primaryTabs
            .map((e) =>
                NavigationDestination(icon: Icon(e.icon), label: e.label))
            .toList(),
      ),
      floatingActionButton: showQuick
          ? QuickActionButton(
              openIcon: Icons.close_rounded,
              closedIcon: Icons.bolt_rounded,
              useExtendedLabelsOnWide: false,
              actions: [
                QuickAction(
                    icon: Icons.point_of_sale_rounded,
                    label: 'Sale (${quickCounts?.sales ?? 0})'),
                QuickAction(
                    icon: Icons.shopping_cart_rounded,
                    label: 'Purchase (${quickCounts?.purchases ?? 0})'),
                QuickAction(
                    icon: Icons.payments_rounded,
                    label: 'Collection (${quickCounts?.collections ?? 0})'),
                QuickAction(
                    icon: Icons.money_off_rounded,
                    label: 'Expense (${quickCounts?.expenses ?? 0})'),
              ],
              onOpenChanged: (open) {
                // Example: dim app bar or log analytics here.
              },
            )
          : null,
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}
