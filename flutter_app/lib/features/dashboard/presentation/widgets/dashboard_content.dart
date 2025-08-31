// lib/dashboard/presentation/dashboard_content.dart
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

    // Responsive grid
    final crossAxisCount = shortest >= 1100
        ? 4
        : shortest >= 900
            ? 3
            : shortest >= 600
                ? 2
                : 1;

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Overview',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: size.width < 900 ? 1.25 : 1.5,
            ),
            delegate: SliverChildListDelegate([
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
                icon: Icons.attach_money_rounded,
                title: 'Daily Cash Summary',
                value: _fmt(metrics?.dailyCashSummary),
                subtitle: 'Cash flow',
                color: Colors.green,
              ),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Shortcuts',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 280,
            child: FeatureGrid(
              items: const [
                FeatureItem(icon: Icons.point_of_sale_rounded, label: 'New Sale'),
                FeatureItem(icon: Icons.description_rounded, label: 'Purchase Order'),
                FeatureItem(icon: Icons.inventory_2_rounded, label: 'Inventory View'),
                FeatureItem(icon: Icons.people_alt_rounded, label: 'Customer View'),
                FeatureItem(icon: Icons.point_of_sale_rounded, label: 'Cash Register'),
                FeatureItem(icon: Icons.bar_chart_rounded, label: 'Reports'),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          sliver: SliverToBoxAdapter(
            child: Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activity',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(3, (i) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(.15),
                          child: Icon(
                            i == 0
                                ? Icons.point_of_sale_rounded
                                : i == 1
                                    ? Icons.description_rounded
                                    : Icons.inventory_2_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          i == 0
                              ? 'New sale created'
                              : i == 1
                                  ? 'PO approved'
                                  : 'Stock adjusted',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '2h ago · by Admin',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant),
                        ),
                      );
                    })
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
