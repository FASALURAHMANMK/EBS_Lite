import 'package:flutter/material.dart';
import 'package:ebs_lite/shared/widgets/feature_grid.dart';

import 'report_category_page.dart';

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
              title: 'Sales Reports',
              reports: const [
                ReportConfig(
                  title: 'Sales Summary',
                  endpoint: 'sales-summary',
                  description: 'Grouped sales totals and outstanding balances.',
                  supportsGroupBy: true,
                ),
                ReportConfig(
                  title: 'Top Products',
                  endpoint: 'top-products',
                  description: 'Best-selling products by revenue.',
                  supportsLimit: true,
                  supportsLocation: false,
                ),
                ReportConfig(
                  title: 'Customer Balances',
                  endpoint: 'customer-balances',
                  description: 'Outstanding balances by customer.',
                  supportsDateRange: false,
                  supportsLocation: false,
                ),
                ReportConfig(
                  title: 'Tax Report',
                  endpoint: 'tax',
                  description: 'Taxable sales and tax amount by tax type.',
                  supportsLocation: false,
                ),
              ],
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
              title: 'Purchase Reports',
              reports: const [
                ReportConfig(
                  title: 'Expenses Summary',
                  endpoint: 'expenses-summary',
                  description: 'Expenses grouped by category or period.',
                  supportsExpensesGroupBy: true,
                  supportsDateRange: false,
                  supportsLocation: false,
                ),
                ReportConfig(
                  title: 'Purchase vs Returns',
                  endpoint: 'purchase-vs-returns',
                  description: 'Compare purchases against returns.',
                ),
                ReportConfig(
                  title: 'Supplier Report',
                  endpoint: 'supplier',
                  description: 'Supplier performance and totals.',
                  supportsDateRange: false,
                  supportsLocation: false,
                ),
              ],
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
              title: 'Accounts Reports',
              reports: const [
                ReportConfig(
                  title: 'Daily Cash',
                  endpoint: 'daily-cash',
                  description: 'Daily cash activity overview.',
                ),
                ReportConfig(
                  title: 'Income vs Expense',
                  endpoint: 'income-expense',
                  description: 'Income and expense comparison.',
                ),
                ReportConfig(
                  title: 'General Ledger',
                  endpoint: 'general-ledger',
                  description: 'General ledger report.',
                ),
                ReportConfig(
                  title: 'Trial Balance',
                  endpoint: 'trial-balance',
                  description: 'Trial balance summary.',
                ),
                ReportConfig(
                  title: 'Profit & Loss',
                  endpoint: 'profit-loss',
                  description: 'Profit and loss statement.',
                ),
                ReportConfig(
                  title: 'Balance Sheet',
                  endpoint: 'balance-sheet',
                  description: 'Balance sheet overview.',
                ),
                ReportConfig(
                  title: 'Outstanding',
                  endpoint: 'outstanding',
                  description: 'Outstanding invoices or payments.',
                ),
                ReportConfig(
                  title: 'Top Performers',
                  endpoint: 'top-performers',
                  description: 'Top performing employees or products.',
                ),
              ],
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
              title: 'Inventory Reports',
              reports: const [
                ReportConfig(
                  title: 'Stock Summary',
                  endpoint: 'stock-summary',
                  description: 'Stock levels and valuation by location.',
                  supportsProductId: true,
                ),
                ReportConfig(
                  title: 'Item Movement',
                  endpoint: 'item-movement',
                  description: 'Stock movement report.',
                ),
                ReportConfig(
                  title: 'Valuation Report',
                  endpoint: 'valuation',
                  description: 'Inventory valuation summary.',
                ),
              ],
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
