import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_empty_view.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../../shared/widgets/app_loading_view.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import 'product_transactions_page.dart';
import 'stock_adjustments_page.dart';

class InventoryOperationsPage extends ConsumerStatefulWidget {
  const InventoryOperationsPage({super.key});

  @override
  ConsumerState<InventoryOperationsPage> createState() =>
      _InventoryOperationsPageState();
}

class _InventoryOperationsPageState
    extends ConsumerState<InventoryOperationsPage> {
  bool _loading = true;
  Object? _error;
  List<InventoryListItem> _items = const [];
  final TextEditingController _search = TextEditingController();
  bool _searching = false;
  List<InventoryListItem> _searchResults = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(inventoryRepositoryProvider).getStock();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runSearch() async {
    final term = _search.text.trim();
    if (term.length < 2) {
      setState(() => _searchResults = const []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results =
          await ref.read(inventoryRepositoryProvider).searchProducts(term);
      if (!mounted) return;
      setState(() => _searchResults = results);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openUtilitySheet(InventoryListItem item) async {
    final repo = ref.read(inventoryRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FutureBuilder<_TrackingBundle>(
        future: _loadTrackingBundle(repo, item),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(ErrorHandler.message(snapshot.error!)),
            );
          }
          final bundle = snapshot.data ?? const _TrackingBundle();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Stock ${item.stock.toStringAsFixed(2)}')),
                    Chip(label: Text('Type ${item.trackingType}')),
                    if ((item.sku ?? '').trim().isNotEmpty)
                      Chip(label: Text('SKU ${item.sku!.trim()}')),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).push(
                          MaterialPageRoute(
                            builder: (_) => ProductTransactionsPage(
                              productId: item.productId,
                              productName: item.name,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history_rounded),
                      label: const Text('Transactions'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).push(
                          MaterialPageRoute(
                            builder: (_) => const StockAdjustmentsPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Adjust stock'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _Section(
                  title: 'Variants',
                  child: bundle.variants.isEmpty
                      ? const Text('No variant records for this item.')
                      : Column(
                          children: bundle.variants
                              .map(
                                (variant) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(variant.displayName),
                                  subtitle: Text(
                                    'Qty ${variant.quantity.toStringAsFixed(2)} • Avg cost ${variant.averageCost.toStringAsFixed(2)}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                _Section(
                  title: 'Batches',
                  child: bundle.batches.isEmpty
                      ? const Text('No active batches at this location.')
                      : Column(
                          children: bundle.batches
                              .map(
                                (batch) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    (batch.batchNumber ?? '').trim().isEmpty
                                        ? 'Batch #${batch.lotId}'
                                        : batch.batchNumber!.trim(),
                                  ),
                                  subtitle: Text(
                                    'Qty ${batch.remainingQuantity.toStringAsFixed(2)}'
                                    '${batch.expiryDate != null ? ' • Exp ${_fmtDate(batch.expiryDate)}' : ''}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                _Section(
                  title: 'Serials',
                  child: bundle.serials.isEmpty
                      ? const Text('No active serials at this location.')
                      : Column(
                          children: bundle.serials
                              .take(20)
                              .map(
                                (serial) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(serial.serialNumber),
                                  subtitle: Text(
                                    (serial.batchNumber ?? '').trim().isEmpty
                                        ? 'Serial tracked'
                                        : 'Batch ${serial.batchNumber!.trim()}',
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<_TrackingBundle> _loadTrackingBundle(
    InventoryRepository repo,
    InventoryListItem item,
  ) async {
    final variants = await repo.getStockVariants(item.productId);
    final batches = await repo.getStockBatches(productId: item.productId);
    final serials = await repo.getAvailableSerials(productId: item.productId);
    return _TrackingBundle(
      variants: variants,
      batches: batches,
      serials: serials,
    );
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '—';
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final lowStock = _items.where((item) => item.isLowStock).toList();
    final stockouts = _items.where((item) => item.stock <= 0).toList();

    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Inventory Operations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const AppLoadingView(label: 'Loading stock operations')
          : _error != null
              ? AppErrorView(error: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Barcode and stock utility',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _search,
                                      decoration: const InputDecoration(
                                        hintText:
                                            'Search by barcode, SKU, or name',
                                        prefixIcon:
                                            Icon(Icons.qr_code_scanner_rounded),
                                      ),
                                      onSubmitted: (_) => _runSearch(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  FilledButton(
                                    onPressed: _searching ? null : _runSearch,
                                    child: _searching
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Find'),
                                  ),
                                ],
                              ),
                              if (_searchResults.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ..._searchResults.take(8).map(
                                      (item) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(
                                          Icons.inventory_2_rounded,
                                        ),
                                        title: Text(item.name),
                                        subtitle: Text(
                                          [
                                            if ((item.sku ?? '')
                                                .trim()
                                                .isNotEmpty)
                                              item.sku!.trim(),
                                            item.trackingType,
                                          ].join(' • '),
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                        onTap: () => _openUtilitySheet(item),
                                      ),
                                    ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 24,
                            runSpacing: 16,
                            children: [
                              _MetricTile(
                                label: 'Low Stock',
                                value: '${lowStock.length}',
                              ),
                              _MetricTile(
                                label: 'Stockouts',
                                value: '${stockouts.length}',
                              ),
                              _MetricTile(
                                label: 'Tracked SKUs',
                                value: '${_items.length}',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Section(
                        title: 'Replenishment Queue',
                        child: lowStock.isEmpty
                            ? const AppEmptyView(
                                title: 'No low stock items',
                                message:
                                    'Items below reorder level will show here.',
                                icon: Icons.inventory_2_outlined,
                              )
                            : Column(
                                children: lowStock
                                    .take(20)
                                    .map(
                                      (item) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(
                                          item.stock <= 0
                                              ? Icons.warning_amber_rounded
                                              : Icons.inventory_2_rounded,
                                        ),
                                        title: Text(item.name),
                                        subtitle: Text(
                                          'Qty ${item.stock.toStringAsFixed(2)} • Reorder ${item.reorderLevel}',
                                        ),
                                        trailing: const Icon(
                                          Icons.chevron_right_rounded,
                                        ),
                                        onTap: () => _openUtilitySheet(item),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _TrackingBundle {
  final List<InventoryVariantStockDto> variants;
  final List<InventoryBatchStockDto> batches;
  final List<InventorySerialStockDto> serials;

  const _TrackingBundle({
    this.variants = const [],
    this.batches = const [],
    this.serials = const [],
  });
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
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
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            child,
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
