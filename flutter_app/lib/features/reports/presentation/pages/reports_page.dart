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
                  endpoint: '/reports/sales-summary',
                  description: 'Grouped sales totals and outstanding balances.',
                  supportsGroupBy: true,
                ),
                ReportConfig(
                  title: 'Top Products',
                  endpoint: '/reports/top-products',
                  description: 'Best-selling products by revenue.',
                  supportsLimit: true,
                  supportsLocation: false,
                ),
                ReportConfig(
                  title: 'Customer Balances',
                  endpoint: '/reports/customer-balances',
                  description: 'Outstanding balances by customer.',
                  supportsDateRange: false,
                  supportsLocation: false,
                ),
                ReportConfig(
                  title: 'Tax Report',
                  endpoint: '/reports/tax',
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
                  endpoint: '/reports/expenses-summary',
                  description: 'Expenses grouped by category or period.',
                  supportsExpensesGroupBy: true,
                  supportsDateRange: false,
                  supportsLocation: false,
                ),
                ReportConfig(
                  title: 'Purchase vs Returns',
                  endpoint: '/reports/purchase-vs-returns',
                  description: 'Compare purchases against returns.',
                ),
                ReportConfig(
                  title: 'Supplier Report',
                  endpoint: '/reports/supplier',
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
                  endpoint: '/reports/daily-cash',
                  description: 'Daily cash activity overview.',
                ),
                ReportConfig(
                  title: 'Income vs Expense',
                  endpoint: '/reports/income-expense',
                  description: 'Income and expense comparison.',
                ),
                ReportConfig(
                  title: 'General Ledger',
                  endpoint: '/reports/general-ledger',
                  description: 'General ledger report.',
                ),
                ReportConfig(
                  title: 'Trial Balance',
                  endpoint: '/reports/trial-balance',
                  description: 'Trial balance summary.',
                ),
                ReportConfig(
                  title: 'Profit & Loss',
                  endpoint: '/reports/profit-loss',
                  description: 'Profit and loss statement.',
                ),
                ReportConfig(
                  title: 'Balance Sheet',
                  endpoint: '/reports/balance-sheet',
                  description: 'Balance sheet overview.',
                ),
                ReportConfig(
                  title: 'Outstanding',
                  endpoint: '/reports/outstanding',
                  description: 'Outstanding invoices or payments.',
                ),
                ReportConfig(
                  title: 'Top Performers',
                  endpoint: '/reports/top-performers',
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
                  endpoint: '/reports/stock-summary',
                  description: 'Stock levels and valuation by location.',
                  supportsProductId: true,
                ),
                ReportConfig(
                  title: 'Item Movement',
                  endpoint: '/reports/item-movement',
                  description: 'Stock movement report.',
                ),
                ReportConfig(
                  title: 'Valuation Report',
                  endpoint: '/reports/valuation',
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
