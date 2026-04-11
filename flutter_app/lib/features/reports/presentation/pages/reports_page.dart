import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_menu.dart';

import '../report_navigation.dart';

class ReportsPage extends StatelessWidget {
  const ReportsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final destination in reportCategoryDestinations)
        FeatureItem(
          icon: destination.icon,
          label: destination.label,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => buildReportCategoryPage(destination),
            ),
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: FeatureMenu(
        items: items,
        title: 'Report categories',
      ),
    );
  }
}
