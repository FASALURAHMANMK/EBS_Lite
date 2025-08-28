import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/shared/pages/feature_detail_page.dart';

class HRPage extends StatelessWidget {
  const HRPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.how_to_reg_rounded,
        label: 'Attendance Register',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Attendance Register')),
        ),
      ),
      FeatureItem(
        icon: Icons.payments_rounded,
        label: 'Payroll Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const FeatureDetailPage(title: 'Payroll Management')),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('HR')),
      body: FeatureGrid(items: items),
    );
  }
}

