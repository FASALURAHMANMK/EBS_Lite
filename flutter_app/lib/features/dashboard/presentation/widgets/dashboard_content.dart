import 'package:flutter/material.dart';

import 'stat_card.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width > 800
        ? 4
        : width > 600
            ? 3
            : 2;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.count(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: const [
          StatCard(title: 'Total Credit Outstanding', value: '$0'),
          StatCard(title: 'Total Inventory Value', value: '$0'),
          StatCard(title: "Today's Sales & Purchases", value: '$0'),
          StatCard(title: 'Daily Cash Summary', value: '$0'),
        ],
      ),
    );
  }
}

