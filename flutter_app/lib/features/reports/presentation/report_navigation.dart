import 'package:flutter/material.dart';

import 'pages/report_category_page.dart';
import 'report_categories.dart';

class ReportCategoryDestination {
  const ReportCategoryDestination({
    required this.label,
    required this.title,
    required this.icon,
    required this.reports,
  });

  final String label;
  final String title;
  final IconData icon;
  final List<ReportConfig> reports;
}

const salesReportDestination = ReportCategoryDestination(
  label: 'Sales',
  title: salesReportCategoryTitle,
  icon: Icons.storefront_rounded,
  reports: salesReports,
);

const purchaseReportDestination = ReportCategoryDestination(
  label: 'Purchase',
  title: purchaseReportCategoryTitle,
  icon: Icons.shopping_cart_rounded,
  reports: purchaseReports,
);

const accountsReportDestination = ReportCategoryDestination(
  label: 'Accounts',
  title: accountsReportCategoryTitle,
  icon: Icons.account_balance_wallet_rounded,
  reports: accountsReports,
);

const inventoryReportDestination = ReportCategoryDestination(
  label: 'Inventory',
  title: inventoryReportCategoryTitle,
  icon: Icons.inventory_2_rounded,
  reports: inventoryReports,
);

const reportCategoryDestinations = <ReportCategoryDestination>[
  salesReportDestination,
  purchaseReportDestination,
  accountsReportDestination,
  inventoryReportDestination,
];

ReportCategoryDestination? reportDestinationForLabel(String label) {
  switch (label) {
    case 'Sales':
    case 'Sales Reports':
      return salesReportDestination;
    case 'Purchase':
    case 'Purchase Reports':
      return purchaseReportDestination;
    case 'Accounts':
    case 'Accounts Reports':
    case 'Accounting Reports':
      return accountsReportDestination;
    case 'Inventory':
    case 'Inventory Reports':
      return inventoryReportDestination;
    default:
      return null;
  }
}

ReportCategoryPage buildReportCategoryPage(
  ReportCategoryDestination destination, {
  bool fromMenu = false,
  void Function(BuildContext context, String label)? onMenuSelect,
}) {
  return ReportCategoryPage(
    title: destination.title,
    reports: destination.reports,
    fromMenu: fromMenu,
    onMenuSelect: onMenuSelect,
  );
}
