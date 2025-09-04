import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import '../../../../shared/pages/feature_detail_page.dart';
import 'stock_adjustments_page.dart';
import 'inventory_management_page.dart';
import 'inventory_view_page.dart';
import 'stock_transfers_page.dart';
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
        label: 'Inventory',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InventoryViewPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.inventory_rounded,
        label: 'Products',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const InventoryManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.swap_horiz_rounded,
        label: 'Stock Transfer',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const StockTransfersPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.tune_rounded,
        label: 'Stock Adjustments',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const StockAdjustmentsPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.category_rounded,
        label: 'Categories',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CategoryManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.branding_watermark_rounded,
        label: 'Brands',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BrandManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.build_rounded,
        label: 'Attributes',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const AttributeManagementPage()),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}
