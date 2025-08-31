import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Sales',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Sales Report')),
        ),
      ),
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Purchase',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Purchase Report')),
        ),
      ),
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Accounts',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Accounts Report')),
        ),
      ),
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Inventory',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Inventory Report')),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: FeatureGrid(items: items),
    );
  }
}

