import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'loyalty_management_page.dart';
import 'customer_management_page.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.manage_accounts_rounded,
        label: 'Customer Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.loyalty_rounded,
        label: 'Loyalty Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoyaltyManagementPage()),
        ),
      ),
    ];

    return FeatureGrid(items: items);
  }
}
