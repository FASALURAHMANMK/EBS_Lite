import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_menu.dart';
import 'collections_workbench_page.dart';
import 'customer_care_hub_page.dart';
import 'loyalty_management_page.dart';
import 'loyalty_gift_redeem_page.dart';
import 'customer_management_page.dart';
import 'customer_warranty_page.dart';

class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.support_agent_rounded,
        label: 'Customer Care Hub',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerCareHubPage()),
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
        icon: Icons.loyalty_rounded,
        label: 'Loyalty Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoyaltyManagementPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.redeem_rounded,
        label: 'Gift Redeem',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoyaltyGiftRedeemPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.verified_user_rounded,
        label: 'Warranty Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CustomerWarrantyPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.payments_rounded,
        label: 'Collections Workbench',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CollectionsWorkbenchPage()),
        ),
      ),
    ];

    return FeatureMenu(items: items, title: 'Customers');
  }
}
