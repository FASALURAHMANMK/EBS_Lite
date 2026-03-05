import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';
import 'package:ebs_lite/features/expenses/presentation/pages/expenses_page.dart';
import 'audit_logs_page.dart';
import 'cash_register_page.dart';
import 'day_end_flow_page.dart';
import 'ledgers_page.dart';
import 'vouchers_page.dart';

class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      FeatureItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Cash Register',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CashRegisterPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.event_available_rounded,
        label: 'Day Open/Close',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DayEndFlowPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.payments_outlined,
        label: 'Expenses',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ExpensesPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.receipt_long_rounded,
        label: 'Vouchers',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const VouchersPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.menu_book_rounded,
        label: 'Ledgers',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LedgersPage()),
        ),
      ),
      FeatureItem(
        icon: Icons.fact_check_rounded,
        label: 'Audit Logs',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AuditLogsPage()),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: FeatureGrid(items: items),
    );
  }
}
