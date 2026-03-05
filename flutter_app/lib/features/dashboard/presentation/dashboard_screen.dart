import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/offline_cache/master_data_sync_notifier.dart';
import '../../../core/layout/app_breakpoints.dart';
import '../../../core/outbox/outbox_notifier.dart';
import '../../../core/theme_notifier.dart';
import 'widgets/dashboard_content.dart';
import 'widgets/dashboard_desktop_sidebar.dart';
import 'widgets/dashboard_header.dart';
import 'widgets/dashboard_sidebar.dart';
import 'widgets/quick_action_button.dart';
import '../controllers/dashboard_notifier.dart';
import '../controllers/dashboard_customization_notifier.dart';
import '../controllers/ui_prefs_notifier.dart';
import '../data/models.dart';
import '../controllers/location_notifier.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/purchases_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/inventory_page.dart';
import 'package:ebs_lite/features/customers/presentation/pages/customers_page.dart';
import 'package:ebs_lite/features/notifications/presentation/pages/notifications_page.dart';
import 'package:ebs_lite/features/notifications/controllers/notifications_providers.dart';
import 'dashboard_navigation.dart';
import 'dashboard_actions.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _promptedLocation = false;
  bool _desktopSidebarExpanded = true;
  final GlobalKey<NavigatorState> _wideNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
  }

  // Primary tabs for bottom navigation
  static const _primaryTabs = <_NavItem>[
    _NavItem('Dashboard', Icons.grid_view_rounded),
    _NavItem('Sales', Icons.storefront_rounded),
    _NavItem('Purchases', Icons.shopping_cart_rounded),
    _NavItem('Inventory', Icons.inventory_2_rounded),
    _NavItem('Customers', Icons.people_alt_rounded),
  ];

  // Secondary items kept in sidebar/rail
  int _bottomIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isTabletOrDesktop = AppBreakpoints.isTabletOrDesktop(context);

    // Reload dashboard data when selected location changes
    ref.listen<LocationState>(locationNotifierProvider, (prev, next) {
      final prevId = prev?.selected?.locationId;
      final nextId = next.selected?.locationId;
      if (nextId != null && nextId != prevId) {
        // fire-and-forget
        // ignore: unawaited_futures
        ref.read(dashboardNotifierProvider.notifier).load();
        // Preload/refresh offline master data for the new location.
        // ignore: unawaited_futures
        ref.read(masterDataSyncNotifierProvider.notifier).syncNow(force: true);
      }
    });

    // When we regain online status, refresh cached masters and reserve offline numbering blocks.
    ref.listen(outboxNotifierProvider, (prev, next) {
      if (next.isOnline && (prev?.isOnline != true)) {
        // ignore: unawaited_futures
        ref.read(masterDataSyncNotifierProvider.notifier).syncNow(force: true);
        // ignore: unawaited_futures
        ref.read(dashboardNotifierProvider.notifier).load(showLoading: false);
      }
      // When queued transactions sync, refresh dashboard KPIs.
      if (next.isOnline && next.lastSyncAt != prev?.lastSyncAt) {
        // ignore: unawaited_futures
        ref.read(dashboardNotifierProvider.notifier).load(showLoading: false);
      }
    });

    // Prompt for location selection if user has multiple locations and none selected
    final locState = ref.watch(locationNotifierProvider);
    if (!_promptedLocation &&
        locState.selected == null &&
        locState.locations.length > 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _promptedLocation = true;
        _showLocationPicker(locState.locations);
      });
    }
    final themeNotifier = ref.read(themeNotifierProvider.notifier);

    final dashboardState = ref.watch(dashboardNotifierProvider);
    final quickCounts = dashboardState.quickActions;

    final theme = Theme.of(context);
    final outboxState = ref.watch(outboxNotifierProvider);
    final outboxNotifier = ref.read(outboxNotifierProvider.notifier);
    // Keep master-data sync alive while the dashboard is active.
    ref.watch(masterDataSyncNotifierProvider);
    final unreadNotifications =
        ref.watch(notificationsUnreadCountProvider).maybeWhen(
              data: (v) => v,
              orElse: () => 0,
            );

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
    final customization = ref.watch(dashboardCustomizationProvider);
    final quickDef = customization.quickActionId == null
        ? null
        : dashboardActionForId(customization.quickActionId!);

    if (!isTabletOrDesktop) {
      return Scaffold(
        appBar: DashboardHeader(
          onToggleTheme: () => themeNotifier.toggle(),
          isOnline: outboxState.isOnline,
          isChecking: outboxState.isChecking,
          queuedCount: outboxState.queuedCount,
          isSyncing: outboxState.isSyncing,
          unreadNotificationsCount: unreadNotifications,
          onRetry: outboxState.queuedCount > 0
              ? () => outboxNotifier.retryNow()
              : null,
          title: currentTitle,
          onNotifications: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsPage()),
            );
          },
        ),
        drawer: DashboardSidebar(
          onSelect: (label) {
            Navigator.of(context).maybePop();
            DashboardNavigation.pushForLabel(context, label);
          },
        ),
        body: IndexedStack(
          index: _bottomIndex,
          children: pages,
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
            ? (quickDef == null
                ? null
                : QuickActionButton(
                    heroTag: 'dashboard_quick_action',
                    useExtendedLabelsOnWide: false,
                    actions: [
                      QuickAction(
                        icon: quickDef.icon,
                        label: _quickLabel(quickDef.id, quickCounts),
                        onTap: () =>
                            runDashboardAction(context, ref, quickDef.id),
                      ),
                    ],
                  ))
            : null,
      );
    }

    void openWide(Widget page) {
      _wideNavigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => page),
      );
    }

    void goWideHome() {
      _wideNavigatorKey.currentState?.popUntil((r) => r.isFirst);
    }

    void toggleDesktopSidebar() {
      setState(() => _desktopSidebarExpanded = !_desktopSidebarExpanded);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final nav = _wideNavigatorKey.currentState;
        if (nav != null && nav.canPop()) {
          nav.pop();
          return;
        }
        Navigator.of(context).pop();
      },
      child: Scaffold(
        body: Row(
          children: [
            SizedBox(
              width: _desktopSidebarExpanded ? 320 : 56,
              child: _desktopSidebarExpanded
                  ? DashboardDesktopSidebar(
                      onHome: goWideHome,
                      onOpen: openWide,
                    )
                  : _CollapsedSidebar(
                      onExpand: toggleDesktopSidebar,
                    ),
            ),
            if (_desktopSidebarExpanded)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: theme.colorScheme.outlineVariant,
              ),
            Expanded(
              child: Navigator(
                key: _wideNavigatorKey,
                onGenerateRoute: (settings) => MaterialPageRoute(
                  settings: settings,
                  builder: (_) => _DashboardWideHome(
                    onOpen: openWide,
                    isSidebarExpanded: _desktopSidebarExpanded,
                    onToggleSidebar: toggleDesktopSidebar,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _quickLabel(String actionId, QuickActionCounts? counts) {
    if (counts == null) {
      return dashboardActionForId(actionId)?.label ?? 'Action';
    }
    switch (actionId) {
      case 'new_sale':
        return 'New Sale (${counts.sales})';
      case 'new_purchase':
        return 'New Purchase (${counts.purchases})';
      case 'new_collection':
        return 'New Collection (${counts.collections})';
      case 'new_expense':
        return 'New Expense (${counts.expenses})';
      default:
        return dashboardActionForId(actionId)?.label ?? 'Action';
    }
  }

  Future<void> _showLocationPicker(List<Location> locations) async {
    final notifier = ref.read(locationNotifierProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Location'),
          content: SizedBox(
            width: 360,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: locations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final loc = locations[index];
                return ListTile(
                  title: Text(loc.name),
                  onTap: () async {
                    await notifier.select(loc);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem(this.label, this.icon);
}

class _DashboardWideHome extends ConsumerWidget {
  const _DashboardWideHome({
    required this.onOpen,
    required this.isSidebarExpanded,
    required this.onToggleSidebar,
  });

  final ValueChanged<Widget> onOpen;
  final bool isSidebarExpanded;
  final VoidCallback onToggleSidebar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeNotifier = ref.read(themeNotifierProvider.notifier);
    final outboxState = ref.watch(outboxNotifierProvider);
    final outboxNotifier = ref.read(outboxNotifierProvider.notifier);
    final unreadNotifications =
        ref.watch(notificationsUnreadCountProvider).maybeWhen(
              data: (v) => v,
              orElse: () => 0,
            );

    return Scaffold(
      appBar: DashboardHeader(
        showSidebarToggle: true,
        isSidebarExpanded: isSidebarExpanded,
        onSidebarToggle: onToggleSidebar,
        onToggleTheme: () => themeNotifier.toggle(),
        isOnline: outboxState.isOnline,
        isChecking: outboxState.isChecking,
        queuedCount: outboxState.queuedCount,
        isSyncing: outboxState.isSyncing,
        unreadNotificationsCount: unreadNotifications,
        onRetry: outboxState.queuedCount > 0
            ? () => outboxNotifier.retryNow()
            : null,
        title: 'Dashboard',
        onNotifications: () => onOpen(const NotificationsPage()),
      ),
      body: const DashboardContent(),
    );
  }
}

class _CollapsedSidebar extends StatelessWidget {
  const _CollapsedSidebar({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            IconButton(
              tooltip: 'Show sidebar',
              icon: const Icon(Icons.menu_rounded),
              onPressed: onExpand,
            ),
          ],
        ),
      ),
    );
  }
}
