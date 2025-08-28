import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';

class PurchasesPage extends StatelessWidget {
  const PurchasesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.description_rounded,
        label: 'Purchase Order',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Purchase Order')),
        ),
      ),
      FeatureItem(
        icon: Icons.receipt_rounded,
        label: 'Goods Receipt Note',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Goods Receipt Note')),
        ),
      ),
      FeatureItem(
        icon: Icons.assignment_return_rounded,
        label: 'Purchase Returns',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Purchase Returns')),
        ),
      ),
      FeatureItem(
        icon: Icons.history_rounded,
        label: 'Purchase History',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Purchase History')),
        ),
      ),
      FeatureItem(
        icon: Icons.local_shipping_rounded,
        label: 'Supplier Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Supplier Management')),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}

