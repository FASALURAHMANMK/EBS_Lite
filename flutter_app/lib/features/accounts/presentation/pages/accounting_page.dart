import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';

class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Cash Register',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Cash Register')),
        ),
      ),
      FeatureItem(
        icon: Icons.today_rounded,
        label: 'Day Open/Close',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Day Open/Close')),
        ),
      ),
      FeatureItem(
        icon: Icons.receipt_long_rounded,
        label: 'Vouchers',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Vouchers')),
        ),
      ),
      FeatureItem(
        icon: Icons.menu_book_rounded,
        label: 'Ledgers',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Ledgers')),
        ),
      ),
      FeatureItem(
        icon: Icons.fact_check_rounded,
        label: 'Audit',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Audit')),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: FeatureGrid(items: items),
    );
  }
}

