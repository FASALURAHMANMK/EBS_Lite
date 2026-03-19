import 'pages/report_category_page.dart';

const salesReportCategoryTitle = 'Sales Reports';
const purchaseReportCategoryTitle = 'Purchase Reports';
const accountsReportCategoryTitle = 'Accounts Reports';
const inventoryReportCategoryTitle = 'Inventory Reports';

const salesReports = <ReportConfig>[
  ReportConfig(
    title: 'Sales Summary',
    endpoint: '/reports/sales-summary',
    description:
        'Sales totals, transaction counts, and unpaid balances by period.',
    supportsGroupBy: true,
  ),
  ReportConfig(
    title: 'Top-Selling Products',
    endpoint: '/reports/top-products',
    description: 'Products ranked by sales revenue and quantity sold.',
    supportsLimit: true,
    supportsLocation: false,
  ),
  ReportConfig(
    title: 'Customer Outstanding Balances',
    endpoint: '/reports/customer-balances',
    description: 'Accounts receivable balances by customer.',
    supportsDateRange: false,
    supportsLocation: false,
  ),
  ReportConfig(
    title: 'Tax Report',
    endpoint: '/reports/tax',
    description: 'Taxable turnover and output tax by tax code or rate.',
    supportsLocation: false,
  ),
];

const purchaseReports = <ReportConfig>[
  ReportConfig(
    title: 'Purchases and Purchase Returns',
    endpoint: '/reports/purchase-vs-returns',
    description:
        'Purchases, returns, net purchases, and unpaid supplier balances.',
  ),
  ReportConfig(
    title: 'Supplier Purchases and Balances',
    endpoint: '/reports/supplier',
    description:
        'Purchases, payments, returns, and outstanding balances by supplier.',
    supportsDateRange: false,
    supportsLocation: false,
  ),
];

const accountsReports = <ReportConfig>[
  ReportConfig(
    title: 'Cash Register Summary',
    endpoint: '/reports/daily-cash',
    description:
        'Opening, movement, expected, closing, and variance values by day.',
  ),
  ReportConfig(
    title: 'Expenses Summary',
    endpoint: '/reports/expenses-summary',
    description:
        'Operating expenses grouped by category and, optionally, by period.',
    supportsExpensesGroupBy: true,
    supportsDateRange: false,
    supportsLocation: false,
  ),
  ReportConfig(
    title: 'Income and Expense Summary',
    endpoint: '/reports/income-expense',
    description: 'Sales, expenses, and net operating result by day.',
  ),
  ReportConfig(
    title: 'General Ledger',
    endpoint: '/reports/general-ledger',
    description:
        'Detailed ledger transactions with account and source references.',
  ),
  ReportConfig(
    title: 'Trial Balance',
    endpoint: '/reports/trial-balance',
    description:
        'Trial balance showing debits, credits, and net balances by ledger.',
  ),
  ReportConfig(
    title: 'Profit & Loss',
    endpoint: '/reports/profit-loss',
    description: 'Revenue, expenses, and net profit for the selected period.',
  ),
  ReportConfig(
    title: 'Balance Sheet',
    endpoint: '/reports/balance-sheet',
    description: 'Assets, liabilities, and equity as of the selected date.',
  ),
  ReportConfig(
    title: 'Receivables and Payables Summary',
    endpoint: '/reports/outstanding',
    description:
        'Summary of outstanding customer receivables and supplier payables.',
  ),
  ReportConfig(
    title: 'Top Performers',
    endpoint: '/reports/top-performers',
    description: 'Top-performing staff or products by sales value.',
  ),
];

const inventoryReports = <ReportConfig>[
  ReportConfig(
    title: 'Stock on Hand Summary',
    endpoint: '/reports/stock-summary',
    description:
        'Stock quantities and carrying values by product and location.',
    supportsProductId: true,
  ),
  ReportConfig(
    title: 'Item Movement',
    endpoint: '/reports/item-movement',
    description: 'Purchases, sales, returns, and adjustments by product.',
  ),
  ReportConfig(
    title: 'Inventory Valuation',
    endpoint: '/reports/valuation',
    description: 'Inventory quantities and carrying values by product.',
  ),
  ReportConfig(
    title: 'Asset Register',
    endpoint: '/reports/asset-register',
    description:
        'Capitalized asset entries with asset tags, classes, status, and values.',
  ),
  ReportConfig(
    title: 'Asset Value Summary',
    endpoint: '/reports/asset-value-summary',
    description:
        'Asset counts and capitalized values summarized by class and status.',
    supportsDateRange: false,
  ),
  ReportConfig(
    title: 'Consumable Consumption',
    endpoint: '/reports/consumable-consumption',
    description:
        'Consumable usage entries by item, category, source, quantity, and cost.',
  ),
  ReportConfig(
    title: 'Consumable Balance',
    endpoint: '/reports/consumable-balance',
    description:
        'Remaining consumable stock quantities and carrying values by item.',
    supportsDateRange: false,
    supportsProductId: false,
  ),
];
