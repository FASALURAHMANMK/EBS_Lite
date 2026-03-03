import 'package:flutter/material.dart';

import '../../accounts/presentation/pages/accounting_page.dart';
import '../../accounts/presentation/pages/audit_logs_page.dart';
import '../../accounts/presentation/pages/cash_register_page.dart';
import '../../accounts/presentation/pages/day_end_flow_page.dart';
import '../../accounts/presentation/pages/ledgers_page.dart';
import '../../accounts/presentation/pages/vouchers_page.dart';
import '../../hr/presentation/pages/attendance_page.dart';
import '../../hr/presentation/pages/hr_page.dart';
import '../../hr/presentation/pages/payroll_page.dart';
import '../../reports/presentation/pages/report_category_page.dart';
import '../../reports/presentation/pages/reports_page.dart';
import '../../reports/presentation/report_categories.dart';
import '../../workflow/presentation/pages/workflow_requests_page.dart';
import 'pages/settings_page.dart';

class DashboardNavigation {
  static void pushForLabel(BuildContext context, String label) {
    final page = pageForLabel(label);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  static Widget pageForLabel(String label) {
    switch (label) {
      case 'Reports':
        return const ReportsPage();
      case 'Sales':
        return const ReportCategoryPage(
          title: salesReportCategoryTitle,
          reports: salesReports,
        );
      case 'Purchase':
        return const ReportCategoryPage(
          title: purchaseReportCategoryTitle,
          reports: purchaseReports,
        );
      case 'Accounts':
        return const ReportCategoryPage(
          title: accountsReportCategoryTitle,
          reports: accountsReports,
        );
      case 'Inventory':
        return const ReportCategoryPage(
          title: inventoryReportCategoryTitle,
          reports: inventoryReports,
        );
      case 'Accounting':
        return const AccountingPage();
      case 'Cash Register':
        return const CashRegisterPage();
      case 'Day Open/Close':
        return const DayEndFlowPage();
      case 'Vouchers':
        return const VouchersPage();
      case 'Ledgers':
        return const LedgersPage();
      case 'Audit':
      case 'Audit Logs':
        return const AuditLogsPage();
      case 'HR':
        return const HRPage();
      case 'Attendance Register':
        return const AttendancePage();
      case 'Payroll Management':
        return const PayrollPage();
      case 'Approvals':
        return const WorkflowRequestsPage();
      case 'Settings':
        return const SettingsPage();
      default:
        return Scaffold(
          appBar: AppBar(title: Text(label)),
          body: Center(
            child: Text('No route configured for: $label'),
          ),
        );
    }
  }
}
