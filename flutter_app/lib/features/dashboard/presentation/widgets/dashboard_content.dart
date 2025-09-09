import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/dashboard_notifier.dart';
import 'stat_card.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';

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
    final metrics = state.metrics;
    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;

    // Loading and error states so we don't show zeros by default
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            state.error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.redAccent),
          ),
        ),
      );
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

    // Non-sliver grid blocks layout
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Text(
          'Overview',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: aspect,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
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
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Shortcuts',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: FeatureGrid(
            items: const [
              FeatureItem(icon: Icons.point_of_sale_rounded, label: 'New Sale'),
              FeatureItem(icon: Icons.inventory_2_rounded, label: 'Products'),
              FeatureItem(icon: Icons.people_alt_rounded, label: 'Customers'),
              FeatureItem(icon: Icons.point_of_sale_rounded, label: 'Cash Register'),
            ],
          ),
        ),
      ],
    );
  }
}
