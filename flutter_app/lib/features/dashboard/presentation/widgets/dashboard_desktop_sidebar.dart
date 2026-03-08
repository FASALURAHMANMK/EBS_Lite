import 'package:ebs_lite/features/auth/controllers/auth_notifier.dart';
import 'package:ebs_lite/features/auth/controllers/auth_permissions_provider.dart';
import 'package:ebs_lite/features/customers/presentation/pages/customer_management_page.dart';
import 'package:ebs_lite/features/customers/presentation/pages/loyalty_management_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/attribute_management_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/brand_management_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/category_management_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/inventory_management_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/inventory_view_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/stock_adjustments_page.dart';
import 'package:ebs_lite/features/inventory/presentation/pages/stock_transfers_page.dart';
import 'package:ebs_lite/features/pos/presentation/pages/pos_page.dart';
import 'package:ebs_lite/features/promotions/presentation/pages/promotions_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/goods_receipts_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/purchase_orders_page.dart';
import 'package:ebs_lite/features/purchases/presentation/pages/purchase_returns_page.dart';
import 'package:ebs_lite/features/reports/presentation/pages/report_category_page.dart';
import 'package:ebs_lite/features/reports/presentation/report_categories.dart';
import 'package:ebs_lite/features/sales/presentation/pages/invoices_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/quotes_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_history_page.dart';
import 'package:ebs_lite/features/sales/presentation/pages/sales_returns_page.dart';
import 'package:ebs_lite/features/suppliers/presentation/pages/suppliers_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../controllers/location_notifier.dart';
import '../dashboard_navigation.dart';
import 'company_logo.dart';

class DashboardDesktopSidebar extends ConsumerWidget {
  const DashboardDesktopSidebar({
    super.key,
    required this.onHome,
    required this.onOpen,
  });

  final VoidCallback onHome;
  final ValueChanged<Widget> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authNotifierProvider);
    final perms = ref.watch(authPermissionsProvider);
    final locationState = ref.watch(locationNotifierProvider);

    final showApprovals = perms.contains('VIEW_WORKFLOWS');

    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Brand header
            Container(
              alignment: Alignment.bottomCenter,
              constraints: const BoxConstraints(minHeight: 156),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primaryContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const CompanyLogo(radius: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          authState.company?.name ?? '',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (locationState.locations.isNotEmpty)
                    DropdownButtonHideUnderline(
                      child: DropdownButton(
                        isExpanded: true,
                        value: locationState.selected,
                        dropdownColor: theme.colorScheme.primaryContainer,
                        iconEnabledColor: Colors.white,
                        items: locationState.locations
                            .map(
                              (l) => DropdownMenuItem(
                                value: l,
                                child: Text(
                                  l.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (loc) {
                          if (loc != null) {
                            ref
                                .read(locationNotifierProvider.notifier)
                                .select(loc);
                          }
                        },
                      ),
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
            _tile(
              context,
              icon: Icons.grid_view_rounded,
              label: 'Dashboard',
              onTap: onHome,
            ),
            const Divider(height: 16),
            _section(
              context,
              icon: Icons.storefront_rounded,
              title: 'Sales',
              children: [
                _child(
                  context,
                  icon: Icons.point_of_sale_rounded,
                  label: 'New Sale',
                  onTap: () => onOpen(const PosPage()),
                ),
                _child(
                  context,
                  icon: Icons.receipt_long_rounded,
                  label: 'Invoices',
                  onTap: () => onOpen(const InvoicesPage()),
                ),
                _child(
                  context,
                  icon: Icons.request_quote_rounded,
                  label: 'Quotes',
                  onTap: () => onOpen(const QuotesPage()),
                ),
                _child(
                  context,
                  icon: Icons.assignment_return_rounded,
                  label: 'Returns',
                  onTap: () => onOpen(const SaleReturnFormPage()),
                ),
                _child(
                  context,
                  icon: Icons.history_rounded,
                  label: 'Sale History',
                  onTap: () => onOpen(const SalesHistoryPage()),
                ),
                _child(
                  context,
                  icon: Icons.percent_rounded,
                  label: 'Promotions',
                  onTap: () => onOpen(const PromotionsPage()),
                ),
              ],
            ),
            _section(
              context,
              icon: Icons.shopping_cart_rounded,
              title: 'Purchases',
              children: [
                _child(
                  context,
                  icon: Icons.description_rounded,
                  label: 'Purchase Order',
                  onTap: () => onOpen(const PurchaseOrdersPage()),
                ),
                _child(
                  context,
                  icon: Icons.receipt_rounded,
                  label: 'Goods Receipt Note',
                  onTap: () => onOpen(const GoodsReceiptsPage()),
                ),
                _child(
                  context,
                  icon: Icons.assignment_return_rounded,
                  label: 'Purchase Returns',
                  onTap: () => onOpen(const PurchaseReturnsPage()),
                ),
                _child(
                  context,
                  icon: Icons.local_shipping_rounded,
                  label: 'Supplier Management',
                  onTap: () => onOpen(const SuppliersPage()),
                ),
              ],
            ),
            _section(
              context,
              icon: Icons.inventory_2_rounded,
              title: 'Inventory',
              children: [
                _child(
                  context,
                  icon: Icons.inventory_2_rounded,
                  label: 'Inventory',
                  onTap: () => onOpen(const InventoryViewPage()),
                ),
                _child(
                  context,
                  icon: Icons.inventory_rounded,
                  label: 'Products',
                  onTap: () => onOpen(const InventoryManagementPage()),
                ),
                _child(
                  context,
                  icon: Icons.swap_horiz_rounded,
                  label: 'Stock Transfer',
                  onTap: () => onOpen(const StockTransfersPage()),
                ),
                _child(
                  context,
                  icon: Icons.tune_rounded,
                  label: 'Stock Adjustments',
                  onTap: () => onOpen(const StockAdjustmentsPage()),
                ),
                _child(
                  context,
                  icon: Icons.category_rounded,
                  label: 'Categories',
                  onTap: () => onOpen(const CategoryManagementPage()),
                ),
                _child(
                  context,
                  icon: Icons.branding_watermark_rounded,
                  label: 'Brands',
                  onTap: () => onOpen(const BrandManagementPage()),
                ),
                _child(
                  context,
                  icon: Icons.build_rounded,
                  label: 'Attributes',
                  onTap: () => onOpen(const AttributeManagementPage()),
                ),
              ],
            ),
            _section(
              context,
              icon: Icons.people_alt_rounded,
              title: 'Customers',
              children: [
                _child(
                  context,
                  icon: Icons.manage_accounts_rounded,
                  label: 'Customer Management',
                  onTap: () => onOpen(const CustomerManagementPage()),
                ),
                _child(
                  context,
                  icon: Icons.loyalty_rounded,
                  label: 'Loyalty Management',
                  onTap: () => onOpen(const LoyaltyManagementPage()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _section(
              context,
              icon: Icons.account_balance_wallet_rounded,
              title: 'Accounts',
              children: [
                _child(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Cash Register',
                  onTap: () => onOpen(
                    DashboardNavigation.pageForLabel('Cash Register'),
                  ),
                ),
                _child(
                  context,
                  icon: Icons.event_available_rounded,
                  label: 'Day Open/Close',
                  onTap: () => onOpen(
                    DashboardNavigation.pageForLabel('Day Open/Close'),
                  ),
                ),
                _child(
                  context,
                  icon: Icons.money_off_rounded,
                  label: 'Expenses',
                  onTap: () =>
                      onOpen(DashboardNavigation.pageForLabel('Expenses')),
                ),
                _child(
                  context,
                  icon: Icons.receipt_long_rounded,
                  label: 'Vouchers',
                  onTap: () =>
                      onOpen(DashboardNavigation.pageForLabel('Vouchers')),
                ),
                _child(
                  context,
                  icon: Icons.menu_book_rounded,
                  label: 'Ledgers',
                  onTap: () =>
                      onOpen(DashboardNavigation.pageForLabel('Ledgers')),
                ),
                _child(
                  context,
                  icon: Icons.shield_rounded,
                  label: 'Audit',
                  onTap: () =>
                      onOpen(DashboardNavigation.pageForLabel('Audit')),
                ),
              ],
            ),
            _section(
              context,
              icon: Icons.groups_2_rounded,
              title: 'HR',
              children: [
                _child(
                  context,
                  icon: Icons.account_tree_rounded,
                  label: 'Departments & Designations',
                  onTap: () => onOpen(
                    DashboardNavigation.pageForLabel(
                        'Departments & Designations'),
                  ),
                ),
                _child(
                  context,
                  icon: Icons.badge_rounded,
                  label: 'Employees',
                  onTap: () =>
                      onOpen(DashboardNavigation.pageForLabel('Employees')),
                ),
                _child(
                  context,
                  icon: Icons.how_to_reg_rounded,
                  label: 'Attendance Register',
                  onTap: () => onOpen(DashboardNavigation.pageForLabel(
                    'Attendance Register',
                  )),
                ),
                _child(
                  context,
                  icon: Icons.payments_rounded,
                  label: 'Payroll Management',
                  onTap: () => onOpen(DashboardNavigation.pageForLabel(
                    'Payroll Management',
                  )),
                ),
              ],
            ),
            _section(
              context,
              icon: Icons.bar_chart_rounded,
              title: 'Reports',
              children: [
                _child(
                  context,
                  icon: Icons.storefront_rounded,
                  label: 'Sales Reports',
                  onTap: () => onOpen(
                    const ReportCategoryPage(
                      title: salesReportCategoryTitle,
                      reports: salesReports,
                    ),
                  ),
                ),
                _child(
                  context,
                  icon: Icons.shopping_cart_rounded,
                  label: 'Purchase Reports',
                  onTap: () => onOpen(
                    const ReportCategoryPage(
                      title: purchaseReportCategoryTitle,
                      reports: purchaseReports,
                    ),
                  ),
                ),
                _child(
                  context,
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'Accounts Reports',
                  onTap: () => onOpen(
                    const ReportCategoryPage(
                      title: accountsReportCategoryTitle,
                      reports: accountsReports,
                    ),
                  ),
                ),
                _child(
                  context,
                  icon: Icons.inventory_2_rounded,
                  label: 'Inventory Reports',
                  onTap: () => onOpen(
                    const ReportCategoryPage(
                      title: inventoryReportCategoryTitle,
                      reports: inventoryReports,
                    ),
                  ),
                ),
              ],
            ),
            if (showApprovals)
              _tile(
                context,
                icon: Icons.approval_rounded,
                label: 'Approvals',
                onTap: () =>
                    onOpen(DashboardNavigation.pageForLabel('Approvals')),
              ),
            _tile(
              context,
              icon: Icons.settings_rounded,
              label: 'Settings',
              onTap: () => onOpen(DashboardNavigation.pageForLabel('Settings')),
            ),
            const Divider(height: 16),
            _tile(
              context,
              icon: Icons.help_outline_rounded,
              label: 'Help & support',
              onTap: () {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Help is on the way! (wire up your help center)'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
            ),
            _tile(
              context,
              icon: Icons.logout_rounded,
              label: 'Logout',
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(authNotifierProvider.notifier).logout();
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  'v1.0.0',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(label),
      horizontalTitleGap: 12,
      onTap: onTap,
    );
  }

  static Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        childrenPadding: const EdgeInsets.only(left: 8),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static Widget _child(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
      title: Text(label),
      contentPadding: const EdgeInsets.only(left: 16, right: 12),
      onTap: onTap,
    );
  }
}
