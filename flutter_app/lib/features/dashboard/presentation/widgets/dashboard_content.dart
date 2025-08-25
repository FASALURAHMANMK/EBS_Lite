// lib/dashboard/presentation/dashboard_content.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/dashboard_notifier.dart';
import 'stat_card.dart';

class DashboardContent extends ConsumerWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardNotifierProvider);
    final metrics = state.metrics;
    final size = MediaQuery.of(context).size;
    final shortest = size.shortestSide;

    // Responsive grid
    final crossAxisCount = shortest >= 1000
        ? 4
        : shortest >= 800
            ? 3
            : shortest >= 500
                ? 2
                : 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GridView(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: constraints.maxWidth < 600 ? 1.2 : 1.4,
              ),
              children: [
                StatCard(
                  icon: Icons.credit_card_rounded,
                  title: 'Total Credit Outstanding',
                  value: '${metrics?.creditOutstanding ?? 0}',
                  subtitle: 'All customers',
                  color: Colors.indigo,
                ),
                StatCard(
                  icon: Icons.inventory_2_rounded,
                  title: 'Total Inventory Value',
                  value: '${metrics?.inventoryValue ?? 0}',
                  subtitle: 'Across warehouses',
                  color: Colors.teal,
                ),
                StatCard(
                  icon: Icons.swap_horiz_rounded,
                  title: "Today's Sales & Purchases",
                  value: '${metrics?.todaySales ?? 0}',
                  subtitle: 'Net transactions',
                  color: Colors.orange,
                ),
                StatCard(
                  icon: Icons.attach_money_rounded,
                  title: 'Daily Cash Summary',
                  value: '${metrics?.dailyCashSummary ?? 0}',
                  subtitle: 'Cash flow',
                  color: Colors.green,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
