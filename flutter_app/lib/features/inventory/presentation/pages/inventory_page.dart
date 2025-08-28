import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.inventory_2_rounded,
        label: 'Inventory View',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Inventory View')),
        ),
      ),
      FeatureItem(
        icon: Icons.inventory_rounded,
        label: 'Inventory Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Inventory Management')),
        ),
      ),
      FeatureItem(
        icon: Icons.swap_horiz_rounded,
        label: 'Stock Transfer',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Stock Transfer')),
        ),
      ),
      FeatureItem(
        icon: Icons.tune_rounded,
        label: 'Stock Adjustments',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Stock Adjustments')),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}

