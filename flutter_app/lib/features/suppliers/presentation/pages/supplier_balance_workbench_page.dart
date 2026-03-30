import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../data/models.dart';
import '../../data/supplier_repository.dart';
import 'supplier_detail_page.dart';

class SupplierBalanceWorkbenchPage extends ConsumerStatefulWidget {
  const SupplierBalanceWorkbenchPage({super.key});

  @override
  ConsumerState<SupplierBalanceWorkbenchPage> createState() =>
      _SupplierBalanceWorkbenchPageState();
}

class _SupplierBalanceWorkbenchPageState
    extends ConsumerState<SupplierBalanceWorkbenchPage> {
  bool _loading = true;
  Object? _error;
  List<SupplierDto> _items = const [];
  final Map<int, bool> _expanded = <int, bool>{};
  final Map<int, List<Map<String, dynamic>>> _purchaseMap = {};
  final Map<int, bool> _purchaseLoading = {};
  final Map<int, String> _purchaseErrors = {};

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
      final suppliers =
          await ref.read(supplierRepositoryProvider).getSuppliers();
      if (!mounted) return;
      setState(() {
        _items = suppliers
            .where((item) => item.outstandingAmount > 0)
            .toList(growable: false);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadPurchases(int supplierId) async {
    if (_purchaseLoading[supplierId] == true ||
        _purchaseMap.containsKey(supplierId)) {
      return;
    }
    setState(() {
      _purchaseLoading[supplierId] = true;
      _purchaseErrors.remove(supplierId);
    });
    try {
      final purchases = await ref
          .read(supplierRepositoryProvider)
          .getOutstandingPurchases(supplierId: supplierId);
      if (!mounted) return;
      setState(() => _purchaseMap[supplierId] = purchases);
    } catch (e) {
      if (!mounted) return;
      setState(() => _purchaseErrors[supplierId] = ErrorHandler.message(e));
    } finally {
      if (mounted) {
        setState(() => _purchaseLoading[supplierId] = false);
      }
    }
  }

  double get _totalOutstanding => _items.fold<double>(
        0,
        (sum, item) => sum + item.outstandingAmount,
      );

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final selectedLocation = ref.watch(locationNotifierProvider).selected;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Supplier Balances'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading supplier balances')
          : _error != null
              ? AppErrorView(error: _error!, onRetry: _load)
              : _items.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: const [
                        SizedBox(height: 64),
                        AppEmptyView(
                          title: 'No supplier balances due',
                          message:
                              'Suppliers with open payable balances will appear here.',
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
                                    label: 'Suppliers',
                                    value: '${_items.length}',
                                  ),
                                  _MetricTile(
                                    label: 'Open Payables',
                                    value: _totalOutstanding.toStringAsFixed(2),
                                  ),
                                  _MetricTile(
                                    label: 'Location Scope',
                                    value: selectedLocation?.name ?? 'Not set',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ..._items.map((item) {
                            final supplierId = item.supplierId;
                            final expanded = _expanded[supplierId] ?? false;
                            final purchaseList =
                                _purchaseMap[supplierId] ?? const [];
                            final purchaseError = _purchaseErrors[supplierId];
                            final purchaseLoading =
                                _purchaseLoading[supplierId] ?? false;

                            return Card(
                              elevation: 0,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ExpansionTile(
                                initiallyExpanded: expanded,
                                onExpansionChanged: (value) {
                                  setState(() => _expanded[supplierId] = value);
                                  if (value) {
                                    _loadPurchases(supplierId);
                                  }
                                },
                                title: Text(
                                  item.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  'Outstanding ${item.outstandingAmount.toStringAsFixed(2)} • ${item.usageLabel}',
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
                                            builder: (_) => SupplierDetailPage(
                                              supplierId: supplierId,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(
                                          Icons.local_shipping_rounded),
                                      label:
                                          const Text('Open supplier account'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  if (purchaseLoading)
                                    const Padding(
                                      padding: EdgeInsets.all(12),
                                      child:
                                          LinearProgressIndicator(minHeight: 2),
                                    )
                                  else if (purchaseError != null)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(purchaseError),
                                    )
                                  else if (purchaseList.isEmpty)
                                    const ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                          'No open purchase invoices returned'),
                                    )
                                  else
                                    ...purchaseList.map(
                                      (purchase) {
                                        final total =
                                            (purchase['total_amount'] as num?)
                                                    ?.toDouble() ??
                                                0;
                                        final paid =
                                            (purchase['paid_amount'] as num?)
                                                    ?.toDouble() ??
                                                0;
                                        final outstanding = (total - paid)
                                            .clamp(0, double.infinity);
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading:
                                              const Icon(Icons.receipt_rounded),
                                          title: Text(
                                            (purchase['purchase_number'] ?? '')
                                                .toString(),
                                          ),
                                          subtitle: Text(
                                            (purchase['status'] ?? '')
                                                .toString(),
                                          ),
                                          trailing: Text(
                                            outstanding.toStringAsFixed(2),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            );
                          }),
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
