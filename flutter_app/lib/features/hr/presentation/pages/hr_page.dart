import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'attendance_page.dart';
import 'departments_designations_page.dart';
import 'employees_page.dart';
import 'payroll_page.dart';

class HRPage extends StatelessWidget {
  const HRPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.account_tree_rounded,
        label: 'Departments & Designations',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => const DepartmentsDesignationsPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.badge_rounded,
        label: 'Employees',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EmployeesPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.how_to_reg_rounded,
        label: 'Attendance Register',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AttendancePage()),
        ),
      ),
      FeatureItem(
        icon: Icons.payments_rounded,
        label: 'Payroll Management',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PayrollPage()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('HR')),
      body: FeatureGrid(items: items),
    );
  }
}
