import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';

import 'report_category_page.dart';
import '../report_categories.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Sales',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportCategoryPage(
              title: salesReportCategoryTitle,
              reports: salesReports,
            ),
          ),
        ),
      ),
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Purchase',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportCategoryPage(
              title: purchaseReportCategoryTitle,
              reports: purchaseReports,
            ),
          ),
        ),
      ),
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Accounts',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportCategoryPage(
              title: accountsReportCategoryTitle,
              reports: accountsReports,
            ),
          ),
        ),
      ),
      FeatureItem(
        icon: Icons.bar_chart_rounded,
        label: 'Inventory',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReportCategoryPage(
              title: inventoryReportCategoryTitle,
              reports: inventoryReports,
            ),
          ),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: FeatureGrid(items: items),
    );
  }
}
