// lib/dashboard/presentation/dashboard_content.dart
import 'package:flutter/material.dart';

import 'stat_card.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
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
              children: const [
                StatCard(
                  icon: Icons.credit_card_rounded,
                  title: 'Total Credit Outstanding',
                  value: '0',
                  subtitle: 'All customers',
                  color: Colors.indigo,
                ),
                StatCard(
                  icon: Icons.inventory_2_rounded,
                  title: 'Total Inventory Value',
                  value: '0',
                  subtitle: 'Across warehouses',
                  color: Colors.teal,
                ),
                StatCard(
                  icon: Icons.swap_horiz_rounded,
                  title: "Today's Sales & Purchases",
                  value: '0',
                  subtitle: 'Net transactions',
                  color: Colors.orange,
                ),
                StatCard(
                  icon: Icons.attach_money_rounded,
                  title: 'Daily Cash Summary',
                  value: '0',
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
