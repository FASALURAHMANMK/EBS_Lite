import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import '../../../../shared/pages/feature_detail_page.dart';
import 'inventory_management_page.dart';
import 'category_management_page.dart';
import 'brand_management_page.dart';
import 'attribute_management_page.dart';

class InventoryPage extends StatelessWidget {
  const InventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.inventory_2_rounded,
        label: 'Product View',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const FeatureDetailPage(title: 'Product View')),
        ),
      ),
      FeatureItem(
        icon: Icons.inventory_rounded,
        label: 'Product Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InventoryManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.swap_horiz_rounded,
        label: 'Stock Transfer',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const FeatureDetailPage(title: 'Stock Transfer')),
        ),
      ),
      FeatureItem(
        icon: Icons.tune_rounded,
        label: 'Stock Adjustments',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) =>
                  const FeatureDetailPage(title: 'Stock Adjustments')),
        ),
      ),
      FeatureItem(
        icon: Icons.category_rounded,
        label: 'Category Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoryManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.branding_watermark_rounded,
        label: 'Brand Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BrandManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.build_rounded,
        label: 'Attribute Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const AttributeManagementPage()),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}
