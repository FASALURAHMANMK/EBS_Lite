import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/dashboard_notifier.dart';
import '../../controllers/dashboard_customization_notifier.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_message_view.dart';
import '../../../../shared/widgets/no_network_view.dart';
import 'stat_card.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import '../dashboard_actions.dart';
import '../pages/dashboard_customization_page.dart';

class DashboardContent extends ConsumerWidget {
  const DashboardContent({super.key});

  String _fmt(num? n) {
    final v = (n ?? 0).toDouble();
    final s = v.toStringAsFixed(2);
    final parts = s.split('.');
    final ints = parts[0];
    final dec = parts[1];
    final buf = StringBuffer();
    for (int i = 0; i < ints.length; i++) {
      final fromEnd = ints.length - i;
      buf.write(ints[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
    }
    return '${buf.toString()}.$dec';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardNotifierProvider);
    final outbox = ref.watch(outboxNotifierProvider);
    final customization = ref.watch(dashboardCustomizationProvider);
    final metrics = state.metrics;
    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;

    // Loading and error states so we don't show zeros by default
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      void onRetry() => ref.read(dashboardNotifierProvider.notifier).load();
      return outbox.isOnline
          ? AppMessageView(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load dashboard',
              message: state.error!,
              onRetry: onRetry,
            )
          : NoNetworkView(onRetry: onRetry);
    }

    // Responsive grid columns
    final crossAxisCount = shortest >= 1100
        ? 4
        : shortest >= 900
            ? 3
            : shortest >= 600
                ? 2
                : 1;
    final aspect = size.width < 900 ? 1.25 : 1.5;

    final shortcutDefs = customization.shortcutActionIds
        .map(dashboardActionForId)
        .whereType<DashboardActionDefinition>()
        .toList();

    final maxShortcutsShown = crossAxisCount >= 3 ? 4 : 6;
    final showCustomize = shortcutDefs.length > maxShortcutsShown;
    final shownShortcuts = showCustomize
        ? shortcutDefs.take(maxShortcutsShown - 1).toList()
        : shortcutDefs.take(maxShortcutsShown).toList();

    // Pure GridView experience as requested (no Slivers)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Overview',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          // Grid takes the remaining space and scrolls
          Expanded(
            child: GridView.count(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: aspect,
              children: [
                StatCard(
                  icon: Icons.credit_card_rounded,
                  title: 'Total Credit Outstanding',
                  value: _fmt(metrics?.creditOutstanding),
                  subtitle: 'All customers',
                  color: Colors.indigo,
                ),
                StatCard(
                  icon: Icons.inventory_2_rounded,
                  title: 'Total Inventory Value',
                  value: _fmt(metrics?.inventoryValue),
                  subtitle: 'Across warehouses',
                  color: Colors.teal,
                ),
                StatCard(
                  icon: Icons.swap_horiz_rounded,
                  title: "Today's Sales",
                  value: _fmt(metrics?.todaySales),
                  subtitle: 'Net transactions',
                  color: Colors.orange,
                ),
                StatCard(
                  icon: Icons.shopping_bag_rounded,
                  title: "Today's Purchases",
                  value: _fmt(metrics?.todayPurchases),
                  subtitle: 'Supplier orders',
                  color: Colors.purple,
                ),
                StatCard(
                  icon: Icons.attach_money_rounded,
                  title: 'Daily Cash Summary',
                  value: _fmt(metrics?.dailyCashSummary),
                  subtitle: 'Cash flow',
                  color: Colors.green,
                ),
                // Shortcuts block as a grid tile
                if (shownShortcuts.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Shortcuts',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: FeatureGrid(
                            padding: EdgeInsets.zero,
                            items: [
                              ...shownShortcuts.map(
                                (a) => FeatureItem(
                                  icon: a.icon,
                                  label: a.label,
                                  onTap: () => runDashboardAction(
                                    context,
                                    ref,
                                    a.id,
                                  ),
                                ),
                              ),
                              if (showCustomize)
                                FeatureItem(
                                  icon: Icons.tune_rounded,
                                  label: 'Customize',
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const DashboardCustomizationPage(),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
