import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/purchase_returns_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/purchase_orders_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/goods_receipts_page.dart';
import '../../../suppliers/presentation/pages/suppliers_page.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.description_rounded,
        label: 'Purchase Order',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PurchaseOrdersPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.receipt_rounded,
        label: 'Goods Receipt Note',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GoodsReceiptsPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.assignment_return_rounded,
        label: 'Purchase Returns',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PurchaseReturnsPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.local_shipping_rounded,
        label: 'Supplier Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SuppliersPage()),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}
