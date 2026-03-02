import 'pages/report_category_page.dart';

const salesReportCategoryTitle = 'Sales Reports';
const purchaseReportCategoryTitle = 'Purchase Reports';
const accountsReportCategoryTitle = 'Accounts Reports';
const inventoryReportCategoryTitle = 'Inventory Reports';

const salesReports = <ReportConfig>[
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
];

const purchaseReports = <ReportConfig>[
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
];

const accountsReports = <ReportConfig>[
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
];

const inventoryReports = <ReportConfig>[
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
];
