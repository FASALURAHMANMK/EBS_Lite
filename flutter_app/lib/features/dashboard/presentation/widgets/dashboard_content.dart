import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/layout/app_breakpoints.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../../shared/widgets/app_message_view.dart';
import '../../../../shared/widgets/app_scrollbar.dart';
import '../../../../shared/widgets/no_network_view.dart';
import '../../controllers/dashboard_customization_notifier.dart';
import '../../controllers/dashboard_notifier.dart';
import '../../data/models.dart';
import '../dashboard_actions.dart';
import '../pages/dashboard_customization_page.dart';
import 'stat_card.dart';

class DashboardContent extends ConsumerStatefulWidget {
  const DashboardContent({super.key});

  @override
  ConsumerState<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends ConsumerState<DashboardContent> {
  late final PageController _statsController;
  int _statsPage = 0;

  static final NumberFormat _moneyFormat = NumberFormat('#,##0.00');
  static final NumberFormat _stockFormat = NumberFormat('#,##0.##');
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _statsController = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _statsController.dispose();
    super.dispose();
  }

  String _formatMoney(num? value) =>
      _moneyFormat.format((value ?? 0).toDouble());

  String _formatStock(num? value) =>
      _stockFormat.format((value ?? 0).toDouble());

  String _formatDate(DateTime? value) {
    if (value == null) return '--';
    return _dateFormat.format(value.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final dashboardTheme = _dashboardTheme(Theme.of(context));
    final state = ref.watch(dashboardNotifierProvider);
    final outbox = ref.watch(outboxNotifierProvider);
    final customization = ref.watch(dashboardCustomizationProvider);
    final metrics = state.metrics;

    if (state.isLoading) {
      return const AppLoadingView(label: 'Loading dashboard');
    }
    if (state.error != null) {
      void onRetry() => ref.read(dashboardNotifierProvider.notifier).load();
      return outbox.isOnline
          ? AppMessageView(
              icon: Icons.error_outline_rounded,
              title: 'Unable to load dashboard',
              message: state.error!,
              onRetry: onRetry,
            )
          : NoNetworkView(onRetry: onRetry);
    }

    final shortcutDefs = customization.shortcutActionIds
        .map(dashboardActionForId)
        .whereType<DashboardActionDefinition>()
        .toList();

    final stats = [
      _StatItem(
        icon: Icons.credit_card_rounded,
        title: 'Total Credit Outstanding',
        value: _formatMoney(metrics?.creditOutstanding),
        subtitle: 'All customers',
        color: Colors.indigo,
      ),
      _StatItem(
        icon: Icons.inventory_2_rounded,
        title: 'Total Inventory Value',
        value: _formatMoney(metrics?.inventoryValue),
        subtitle: 'Across warehouses',
        color: Colors.teal,
      ),
      _StatItem(
        icon: Icons.swap_horiz_rounded,
        title: "Today's Sales",
        value: _formatMoney(metrics?.todaySales),
        subtitle: 'Net transactions',
        color: Colors.orange,
      ),
      _StatItem(
        icon: Icons.shopping_bag_rounded,
        title: "Today's Purchases",
        value: _formatMoney(metrics?.todayPurchases),
        subtitle: 'Supplier orders',
        color: Colors.purple,
      ),
      _StatItem(
        icon: Icons.payments_rounded,
        title: 'Daily Cash Summary',
        value: _formatMoney(metrics?.dailyCashSummary),
        subtitle: 'Cash in minus cash out',
        color: Colors.green,
      ),
    ];

    return Theme(
      data: dashboardTheme,
      child: Padding(
        padding: AppBreakpoints.pagePadding(context),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isPhone = !AppBreakpoints.isTabletOrDesktop(context);
            final isDesktop = AppBreakpoints.isDesktop(context);
            final useSplitLayout = constraints.maxWidth >= 920;

            final maxShortcutsShown = useSplitLayout ? 4 : 6;
            final showCustomize = shortcutDefs.length > maxShortcutsShown;
            final shownShortcuts = showCustomize
                ? shortcutDefs.take(maxShortcutsShown - 1).toList()
                : shortcutDefs.take(maxShortcutsShown).toList();

            return AppScrollbar(
              builder: (context, controller) => SingleChildScrollView(
                controller: controller,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Overview',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Auto-refreshing cash flow, stock alerts, and shortcuts in one place.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _StatsSection(
                      items: stats,
                      isPhone: isPhone,
                      isDesktop: isDesktop,
                      controller: _statsController,
                      currentPage: _statsPage,
                      onPageChanged: (index) =>
                          setState(() => _statsPage = index),
                    ),
                    const SizedBox(height: 18),
                    if (useSplitLayout)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 7,
                            child: _TransactionsPanel(
                              transactions: state.recentTransactions,
                              formatDate: _formatDate,
                              formatMoney: _formatMoney,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                _LowStockPanel(
                                  items: state.lowStockItems,
                                  formatStock: _formatStock,
                                ),
                                if (shownShortcuts.isNotEmpty) ...[
                                  const SizedBox(height: 16),
                                  _ShortcutsPanel(
                                    actions: shownShortcuts,
                                    showCustomize: showCustomize,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _TransactionsPanel(
                        transactions: state.recentTransactions,
                        formatDate: _formatDate,
                        formatMoney: _formatMoney,
                      ),
                      const SizedBox(height: 16),
                      _LowStockPanel(
                        items: state.lowStockItems,
                        formatStock: _formatStock,
                      ),
                      if (shownShortcuts.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _ShortcutsPanel(
                          actions: shownShortcuts,
                          showCustomize: showCustomize,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.items,
    required this.isPhone,
    required this.isDesktop,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  final List<_StatItem> items;
  final bool isPhone;
  final bool isDesktop;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (isPhone) {
      return Column(
        children: [
          SizedBox(
            height: 148,
            child: PageView.builder(
              controller: controller,
              itemCount: items.length,
              onPageChanged: onPageChanged,
              itemBuilder: (context, index) {
                final item = items[index];
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == items.length - 1 ? 0 : 10,
                  ),
                  child: StatCard(
                    title: item.title,
                    value: item.value,
                    subtitle: item.subtitle,
                    icon: item.icon,
                    color: item.color,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              items.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: currentPage == index ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: currentPage == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (isDesktop) {
      return SizedBox(
        height: 148,
        child: Row(
          children: [
            for (int index = 0; index < items.length; index++) ...[
              Expanded(
                child: StatCard(
                  title: items[index].title,
                  value: items[index].value,
                  subtitle: items[index].subtitle,
                  icon: items[index].icon,
                  color: items[index].color,
                ),
              ),
              if (index != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      );
    }

    return SizedBox(
      height: 148,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int index = 0; index < items.length; index++) ...[
              SizedBox(
                width: 220,
                child: StatCard(
                  title: items[index].title,
                  value: items[index].value,
                  subtitle: items[index].subtitle,
                  icon: items[index].icon,
                  color: items[index].color,
                ),
              ),
              if (index != items.length - 1) const SizedBox(width: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _TransactionsPanel extends StatelessWidget {
  const _TransactionsPanel({
    required this.transactions,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<DashboardCashFlowTransaction> transactions;
  final String Function(DateTime?) formatDate;
  final String Function(num?) formatMoney;

  @override
  Widget build(BuildContext context) {
    final isPhone = !AppBreakpoints.isTabletOrDesktop(context);

    return _DashboardPanel(
      title: 'Recent Cash Flow',
      subtitle: 'Sales, returns, collections, purchases, and expenses.',
      child: transactions.isEmpty
          ? const _EmptyState(
              icon: Icons.receipt_long_rounded,
              title: 'No recent transactions',
              message: 'New cash flow activity will appear here automatically.',
            )
          : isPhone
              ? Column(
                  children: [
                    for (int index = 0;
                        index < transactions.length;
                        index++) ...[
                      _TransactionMobileTile(
                        item: transactions[index],
                        formatDate: formatDate,
                        formatMoney: formatMoney,
                      ),
                      if (index != transactions.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                )
              : _TransactionsTable(
                  transactions: transactions,
                  formatDate: formatDate,
                  formatMoney: formatMoney,
                ),
    );
  }
}

class _TransactionsTable extends StatelessWidget {
  const _TransactionsTable({
    required this.transactions,
    required this.formatDate,
    required this.formatMoney,
  });

  final List<DashboardCashFlowTransaction> transactions;
  final String Function(DateTime?) formatDate;
  final String Function(num?) formatMoney;

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w800,
        );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Date', style: headerStyle)),
                Expanded(
                  flex: 4,
                  child: Text('Transaction', style: headerStyle),
                ),
                Expanded(flex: 5, child: Text('Entity', style: headerStyle)),
                Expanded(
                  flex: 3,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('Amount', style: headerStyle),
                  ),
                ),
                Expanded(flex: 3, child: Text('Status', style: headerStyle)),
              ],
            ),
          ),
          for (int index = 0; index < transactions.length; index++) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      formatDate(transactions[index].occurredAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: _TransactionTypeCell(item: transactions[index]),
                  ),
                  Expanded(
                    flex: 5,
                    child: _TransactionEntityCell(item: transactions[index]),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${transactions[index].flowDirection.toUpperCase() == 'IN' ? '+' : '-'}${formatMoney(transactions[index].amount)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _amountColor(context, transactions[index]),
                            ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _StatusBadge(status: transactions[index].status),
                    ),
                  ),
                ],
              ),
            ),
            if (index != transactions.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _LowStockPanel extends StatelessWidget {
  const _LowStockPanel({
    required this.items,
    required this.formatStock,
  });

  final List<DashboardLowStockItem> items;
  final String Function(num?) formatStock;

  @override
  Widget build(BuildContext context) {
    final isPhone = !AppBreakpoints.isTabletOrDesktop(context);

    return _DashboardPanel(
      title: 'Low Stock Alerts',
      subtitle: 'Items that need replenishment soon.',
      child: items.isEmpty
          ? const _SufficientStockCard()
          : isPhone
              ? Column(
                  children: [
                    for (int index = 0; index < items.length; index++) ...[
                      _LowStockMobileTile(
                        item: items[index],
                        formatStock: formatStock,
                      ),
                      if (index != items.length - 1) const Divider(height: 1),
                    ],
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minWidth: constraints.maxWidth),
                      child: DataTable(
                        headingRowHeight: 42,
                        dataRowMinHeight: 50,
                        dataRowMaxHeight: 56,
                        horizontalMargin: 12,
                        columnSpacing: 18,
                        columns: const [
                          DataColumn(label: Text('Item Name')),
                          DataColumn(
                            numeric: true,
                            label: Text('Current Stock'),
                          ),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: items
                            .map(
                              (item) => DataRow(
                                cells: [
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 220,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.productName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (item.locationName.isNotEmpty)
                                            Text(
                                              item.locationName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall
                                                  ?.copyWith(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      formatStock(item.currentStock),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  DataCell(
                                    _SeverityBadge(
                                      severity: item.severity,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _ShortcutsPanel extends ConsumerWidget {
  const _ShortcutsPanel({
    required this.actions,
    required this.showCustomize,
  });

  final List<DashboardActionDefinition> actions;
  final bool showCustomize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _DashboardPanel(
      title: 'Quick Shortcuts',
      subtitle: 'Jump into common dashboard actions.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 12.0;
          final columns = constraints.maxWidth >= 340 ? 2 : 1;
          final itemWidth = columns == 1
              ? constraints.maxWidth
              : (constraints.maxWidth - spacing) / 2;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [
              for (final action in actions)
                SizedBox(
                  width: itemWidth,
                  child: _ShortcutTile(
                    icon: action.icon,
                    label: action.label,
                    onTap: () => runDashboardAction(context, ref, action.id),
                  ),
                ),
              if (showCustomize)
                SizedBox(
                  width: itemWidth,
                  child: _ShortcutTile(
                    icon: Icons.tune_rounded,
                    label: 'Customize',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const DashboardCustomizationPage(),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

class _TransactionMobileTile extends StatelessWidget {
  const _TransactionMobileTile({
    required this.item,
    required this.formatDate,
    required this.formatMoney,
  });

  final DashboardCashFlowTransaction item;
  final String Function(DateTime?) formatDate;
  final String Function(num?) formatMoney;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatDate(item.occurredAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const Spacer(),
              _StatusBadge(status: item.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _TransactionTypeCell(item: item)),
              const SizedBox(width: 12),
              Text(
                '${item.flowDirection.toUpperCase() == 'IN' ? '+' : '-'}${formatMoney(item.amount)}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _amountColor(context, item),
                    ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.entityName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          if ((item.referenceNumber ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                item.referenceNumber!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LowStockMobileTile extends StatelessWidget {
  const _LowStockMobileTile({
    required this.item,
    required this.formatStock,
  });

  final DashboardLowStockItem item;
  final String Function(num?) formatStock;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (item.locationName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.locationName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                const SizedBox(height: 6),
                Text(
                  'Current stock: ${formatStock(item.currentStock)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SeverityBadge(severity: item.severity),
        ],
      ),
    );
  }
}

class _TransactionTypeCell extends StatelessWidget {
  const _TransactionTypeCell({required this.item});

  final DashboardCashFlowTransaction item;

  @override
  Widget build(BuildContext context) {
    final color = _transactionColor(item.transactionType, Theme.of(context));
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(
            _transactionIcon(item.transactionType),
            size: 15,
            color: color,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _transactionLabel(item.transactionType),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    );
  }
}

class _TransactionEntityCell extends StatelessWidget {
  const _TransactionEntityCell({required this.item});

  final DashboardCashFlowTransaction item;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.entityName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if ((item.referenceNumber ?? '').isNotEmpty)
          Text(
            item.referenceNumber!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors(status, Theme.of(context));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _titleize(status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SeverityBadge extends StatelessWidget {
  const _SeverityBadge({required this.severity});

  final String severity;

  @override
  Widget build(BuildContext context) {
    final normalized = severity.toUpperCase();
    final isCritical = normalized == 'CRITICAL';
    final background = isCritical
        ? Colors.red.withValues(alpha: 0.14)
        : Colors.orange.withValues(alpha: 0.16);
    final foreground =
        isCritical ? Colors.red.shade700 : Colors.orange.shade800;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _titleize(normalized),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 86),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: theme.colorScheme.onSurface),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _SufficientStockCard extends StatelessWidget {
  const _SufficientStockCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: Colors.green.withValues(alpha: 0.14),
            child: Icon(
              Icons.inventory_rounded,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'All items are in sufficient stock',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.green.shade800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'No low stock products need attention right now.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
}

class _BadgeColors {
  const _BadgeColors({
    required this.background,
    required this.foreground,
  });

  final Color background;
  final Color foreground;
}

ThemeData _dashboardTheme(ThemeData theme) {
  return theme.copyWith(
    textTheme: _scaledTextTheme(theme.textTheme, 0.94),
  );
}

TextTheme _scaledTextTheme(TextTheme textTheme, double factor) {
  TextStyle? scale(TextStyle? style) {
    if (style?.fontSize == null) return style;
    return style!.copyWith(fontSize: style.fontSize! * factor);
  }

  return textTheme.copyWith(
    displayLarge: scale(textTheme.displayLarge),
    displayMedium: scale(textTheme.displayMedium),
    displaySmall: scale(textTheme.displaySmall),
    headlineLarge: scale(textTheme.headlineLarge),
    headlineMedium: scale(textTheme.headlineMedium),
    headlineSmall: scale(textTheme.headlineSmall),
    titleLarge: scale(textTheme.titleLarge),
    titleMedium: scale(textTheme.titleMedium),
    titleSmall: scale(textTheme.titleSmall),
    bodyLarge: scale(textTheme.bodyLarge),
    bodyMedium: scale(textTheme.bodyMedium),
    bodySmall: scale(textTheme.bodySmall),
    labelLarge: scale(textTheme.labelLarge),
    labelMedium: scale(textTheme.labelMedium),
    labelSmall: scale(textTheme.labelSmall),
  );
}

Color _amountColor(BuildContext context, DashboardCashFlowTransaction item) {
  return item.flowDirection.toUpperCase() == 'IN'
      ? Colors.green.shade700
      : Colors.red.shade700;
}

Color _transactionColor(String type, ThemeData theme) {
  switch (type.toUpperCase()) {
    case 'SALE':
      return Colors.green.shade700;
    case 'SALE_RETURN':
      return Colors.red.shade700;
    case 'COLLECTION':
      return Colors.teal.shade700;
    case 'PURCHASE':
      return Colors.deepPurple.shade700;
    case 'PURCHASE_RETURN':
      return Colors.blue.shade700;
    case 'EXPENSE':
      return Colors.orange.shade800;
    default:
      return theme.colorScheme.primary;
  }
}

IconData _transactionIcon(String type) {
  switch (type.toUpperCase()) {
    case 'SALE':
      return Icons.point_of_sale_rounded;
    case 'SALE_RETURN':
      return Icons.undo_rounded;
    case 'COLLECTION':
      return Icons.payments_rounded;
    case 'PURCHASE':
      return Icons.shopping_bag_rounded;
    case 'PURCHASE_RETURN':
      return Icons.assignment_return_rounded;
    case 'EXPENSE':
      return Icons.receipt_long_rounded;
    default:
      return Icons.swap_horiz_rounded;
  }
}

String _transactionLabel(String type) {
  switch (type.toUpperCase()) {
    case 'SALE':
      return 'Sale';
    case 'SALE_RETURN':
      return 'Sale Return';
    case 'COLLECTION':
      return 'Collection';
    case 'PURCHASE':
      return 'Purchase';
    case 'PURCHASE_RETURN':
      return 'Purchase Return';
    case 'EXPENSE':
      return 'Expense';
    default:
      return _titleize(type);
  }
}

_BadgeColors _statusColors(String status, ThemeData theme) {
  final normalized = status.toUpperCase();
  if (normalized.contains('PAID') ||
      normalized.contains('COMPLETE') ||
      normalized.contains('POSTED') ||
      normalized.contains('COLLECT')) {
    return _BadgeColors(
      background: Colors.green.withValues(alpha: 0.14),
      foreground: Colors.green.shade700,
    );
  }
  if (normalized.contains('PENDING') ||
      normalized.contains('DRAFT') ||
      normalized.contains('HOLD')) {
    return _BadgeColors(
      background: Colors.orange.withValues(alpha: 0.16),
      foreground: Colors.orange.shade800,
    );
  }
  if (normalized.contains('VOID') || normalized.contains('RETURN')) {
    return _BadgeColors(
      background: Colors.red.withValues(alpha: 0.14),
      foreground: Colors.red.shade700,
    );
  }
  return _BadgeColors(
    background: theme.colorScheme.primary.withValues(alpha: 0.12),
    foreground: theme.colorScheme.primary,
  );
}

String _titleize(String value) {
  final source = value.trim();
  if (source.isEmpty) return '--';
  return source
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.isNotEmpty)
      .map(
        (part) => '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}
