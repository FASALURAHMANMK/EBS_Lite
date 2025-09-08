import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';
import 'customer_management_page.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.people_outline_rounded,
        label: 'Customer View',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Customer View')),
        ),
      ),
      FeatureItem(
        icon: Icons.manage_accounts_rounded,
        label: 'Customer Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.payments_rounded,
        label: 'Credit Collection Entry',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Credit Collection Entry')),
        ),
      ),
      FeatureItem(
        icon: Icons.loyalty_rounded,
        label: 'Loyalty Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Loyalty Management')),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}
