import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';
import 'package:ebs_lite/features/pos/presentation/pages/pos_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_history_page.dart';

class SalesPage extends StatelessWidget {
  const SalesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.point_of_sale_rounded,
        label: 'New Sale',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PosPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.receipt_long_rounded,
        label: 'Invoices',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const FeatureDetailPage(title: 'Invoices')),
        ),
      ),
      FeatureItem(
        icon: Icons.request_quote_rounded,
        label: 'Quotes',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const FeatureDetailPage(title: 'Quotes')),
        ),
      ),
      FeatureItem(
        icon: Icons.assignment_return_rounded,
        label: 'Returns',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const FeatureDetailPage(title: 'Returns')),
        ),
      ),
      FeatureItem(
        icon: Icons.history_rounded,
        label: 'Sale History',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const SalesHistoryPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.local_offer_rounded,
        label: 'Promotions',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const FeatureDetailPage(title: 'Promotions')),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}
