import 'package:flutter/material.dart';

import '../../accounts/presentation/pages/accounting_page.dart';
import '../../accounts/presentation/pages/audit_logs_page.dart';
import '../../accounts/presentation/pages/banking_page.dart';
import '../../accounts/presentation/pages/cash_register_page.dart';
import '../../accounts/presentation/pages/chart_of_accounts_page.dart';
import '../../accounts/presentation/pages/day_end_flow_page.dart';
import '../../accounts/presentation/pages/finance_integrity_page.dart';
import '../../accounts/presentation/pages/ledgers_page.dart';
import '../../accounts/presentation/pages/period_close_page.dart';
import '../../accounts/presentation/pages/vouchers_page.dart';
import '../../customers/presentation/pages/customer_care_hub_page.dart';
import '../../customers/presentation/pages/collections_workbench_page.dart';
import '../../expenses/presentation/pages/expense_categories_page.dart';
import '../../expenses/presentation/pages/expenses_page.dart';
import '../../hr/presentation/pages/attendance_page.dart';
import '../../hr/presentation/pages/departments_designations_page.dart';
import '../../hr/presentation/pages/employees_page.dart';
import '../../hr/presentation/pages/hr_page.dart';
import '../../hr/presentation/pages/payroll_page.dart';
import '../../inventory/presentation/pages/combo_definitions_page.dart';
import '../../reports/presentation/pages/report_category_page.dart';
import '../../reports/presentation/pages/reports_page.dart';
import '../../reports/presentation/report_categories.dart';
import '../../suppliers/presentation/pages/supplier_balance_workbench_page.dart';
import '../../workflow/presentation/pages/workflow_requests_page.dart';
import '../../workflow/presentation/pages/approvals_hub_page.dart';
import 'pages/help_support_page.dart';
import 'pages/settings_page.dart';

typedef DashboardMenuSelectHandler = void Function(
  BuildContext context,
  String label,
);

class DashboardNavigation {
  static void pushForLabel(
    BuildContext context,
    String label, {
    bool fromMenu = false,
  }) {
    final page = pageForLabel(
      label,
      fromMenu: fromMenu,
      onMenuSelect: fromMenu ? _handleMenuSelect : null,
    );
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  static Widget pageForLabel(
    String label, {
    bool fromMenu = false,
    DashboardMenuSelectHandler? onMenuSelect,
  }) {
    switch (label) {
      case 'Reports':
        return const ReportsPage();
      case 'Sales':
      case 'Sales Reports':
        return ReportCategoryPage(
          title: salesReportCategoryTitle,
          reports: salesReports,
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Purchase':
      case 'Purchase Reports':
        return ReportCategoryPage(
          title: purchaseReportCategoryTitle,
          reports: purchaseReports,
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Accounts':
      case 'Accounts Reports':
      case 'Accounting Reports':
        return ReportCategoryPage(
          title: accountsReportCategoryTitle,
          reports: accountsReports,
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Inventory':
      case 'Inventory Reports':
        return ReportCategoryPage(
          title: inventoryReportCategoryTitle,
          reports: inventoryReports,
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Accounting':
        return const AccountingPage();
      case 'Banking':
        return const BankingPage();
      case 'Cash Register':
        return CashRegisterPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Chart of Accounts':
        return const ChartOfAccountsPage();
      case 'Day Open/Close':
        return DayEndFlowPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Expenses':
        return ExpensesPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Expense Categories':
        return ExpenseCategoriesPage(
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Vouchers':
        return VouchersPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Ledgers':
        return LedgersPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Period Close':
        return const PeriodClosePage();
      case 'Finance Integrity':
        return FinanceIntegrityPage(
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Audit':
      case 'Audit Logs':
        return AuditLogsPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'HR':
        return const HRPage();
      case 'Employees':
        return EmployeesPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Departments & Designations':
      case 'Departments':
      case 'Employee Roles':
        return DepartmentsDesignationsPage(
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Attendance Register':
        return AttendancePage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Payroll Management':
        return PayrollPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Approvals':
      case 'Leave Approvals':
        return ApprovalsHubPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Workflow Approvals':
        return WorkflowRequestsPage(
          fromMenu: fromMenu,
          onMenuSelect: onMenuSelect,
        );
      case 'Settings':
        return SettingsPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Help & support':
      case 'Help & Support':
        return HelpSupportPage(fromMenu: fromMenu, onMenuSelect: onMenuSelect);
      case 'Customer Care Hub':
        return const CustomerCareHubPage();
      case 'Collections Workbench':
        return const CollectionsWorkbenchPage();
      case 'Supplier Balances':
        return const SupplierBalanceWorkbenchPage();
      case 'Combo Definitions':
        return const ComboDefinitionsPage();
      default:
        return Scaffold(
          appBar: AppBar(title: Text(label)),
          body: Center(
            child: Text('No route configured for: $label'),
          ),
        );
    }
  }

  static void _handleMenuSelect(BuildContext context, String label) {
    if (label == 'Dashboard') {
      Navigator.of(context).popUntil((r) => r.isFirst);
      return;
    }

    final page = pageForLabel(
      label,
      fromMenu: true,
      onMenuSelect: _handleMenuSelect,
    );
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
