import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../data/customer_repository.dart';
import '../../data/models.dart';
import '../widgets/quick_collection_sheet.dart';
import 'customer_detail_page.dart';

class CollectionsWorkbenchPage extends ConsumerStatefulWidget {
  const CollectionsWorkbenchPage({super.key});

  @override
  ConsumerState<CollectionsWorkbenchPage> createState() =>
      _CollectionsWorkbenchPageState();
}

class _CollectionsWorkbenchPageState
    extends ConsumerState<CollectionsWorkbenchPage> {
  bool _loading = true;
  Object? _error;
  List<OutstandingCustomerDto> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list =
          await ref.read(customerRepositoryProvider).getOutstandingCustomers();
      if (!mounted) return;
      setState(() => _items = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openQuickCollection() async {
    final changed = await showQuickCollectionSheet(context, ref);
    if (changed == true && mounted) {
      await _load();
    }
  }

  double get _totalOutstanding => _items.fold<double>(
        0,
        (sum, item) => sum + item.outstandingAmount,
      );

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Collections Workbench'),
        actions: [
          IconButton(
            tooltip: 'Quick collection',
            onPressed: _openQuickCollection,
            icon: const Icon(Icons.payments_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading receivables')
          : _error != null
              ? AppErrorView(error: _error!, onRetry: _load)
              : _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 64),
                        AppEmptyView(
                          title: 'No outstanding customer balances',
                          message:
                              'Customers with unpaid invoices will appear here.',
                          icon: Icons.task_alt_rounded,
                        ),
                      ],
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Card(
                            elevation: 0,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Wrap(
                                spacing: 24,
                                runSpacing: 16,
                                children: [
                                  _MetricTile(
                                    label: 'Customers',
                                    value: '${_items.length}',
                                  ),
                                  _MetricTile(
                                    label: 'Outstanding',
                                    value: _totalOutstanding.toStringAsFixed(2),
                                  ),
                                  FilledButton.icon(
                                    onPressed: _openQuickCollection,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Record Collection'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._items.map(
                            (item) => Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                title: Text(
                                  item.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  '${item.invoices.length} invoice(s) • Outstanding ${item.outstandingAmount.toStringAsFixed(2)}',
                                ),
                                childrenPadding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => CustomerDetailPage(
                                              customerId: item.customerId,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.person_rounded),
                                      label:
                                          const Text('Open customer account'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (item.invoices.isEmpty)
                                    const ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text('No invoice lines returned'),
                                    )
                                  else
                                    ...item.invoices.map(
                                      (invoice) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.receipt_long_rounded,
                                        ),
                                        title: Text(invoice.saleNumber),
                                        subtitle:
                                            Text('Sale #${invoice.saleId}'),
                                        trailing: Text(
                                          invoice.amountDue.toStringAsFixed(2),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}
