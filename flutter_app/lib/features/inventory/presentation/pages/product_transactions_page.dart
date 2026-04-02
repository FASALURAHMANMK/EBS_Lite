import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ebs_lite/core/layout/app_breakpoints.dart';
import 'package:ebs_lite/shared/widgets/desktop_sidebar_toggle_action.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/locale_preferences.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../../../../shared/widgets/app_error_view.dart';
import '../../../purchases/presentation/pages/grn_detail_page.dart';
import '../../../purchases/presentation/pages/purchase_return_detail_page.dart';
import '../../../purchases/presentation/pages/supplier_debit_notes_page.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import 'stock_transfer_view_page.dart';
import 'stock_adjustments_page.dart';
import 'stock_adjustment_document_detail_page.dart';

class ProductTransactionsPage extends ConsumerStatefulWidget {
  const ProductTransactionsPage(
      {super.key, required this.productId, required this.productName});
  final int productId;
  final String
      productName; // kept for backward compatibility (not shown in header)

  @override
  ConsumerState<ProductTransactionsPage> createState() =>
      _ProductTransactionsPageState();
}

class _ProductBundle {
  final ProductDto product;
  final InventoryListItem? stock;
  final List<InventoryVariantStockDto> variants;
  final List<ProductStorageAssignmentDto> storageAssignments;
  final List<ProductTransactionDto> transactions;
  _ProductBundle(
      {required this.product,
      required this.stock,
      required this.variants,
      required this.storageAssignments,
      required this.transactions});
}

class _ProductTransactionsPageState
    extends ConsumerState<ProductTransactionsPage> {
  late Future<_ProductBundle> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _openTransaction(ProductTransactionDto t) async {
    // Route based on backend-provided entity/type
    switch (t.entity) {
      case 'goods_receipt':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) =>
                  GoodsReceiptDetailPage(goodsReceiptId: t.entityId)),
        );
        break;
      case 'transfer':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => StockTransferViewPage(transferId: t.entityId)),
        );
        break;
      case 'purchase_return':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) => PurchaseReturnDetailPage(returnId: t.entityId)),
        );
        break;
      case 'stock_adjustment_document':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
              builder: (_) =>
                  StockAdjustmentDocumentDetailPage(documentId: t.entityId)),
        );
        break;
      case 'stock_adjustment':
        if (!mounted) return;
        // No direct detail view for single adjustments; open documents page for context.
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StockAdjustmentsPage()),
        );
        break;
      case 'supplier_debit_note':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SupplierDebitNotesPage()),
        );
        break;
      // Future: add sale/sale_return/purchase_return when detail pages exist
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text('Detail view not available for this transaction')));
    }
  }

  Future<_ProductBundle> _load() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final locationId = ref.read(locationNotifierProvider).selected?.locationId;
    final results = await Future.wait<dynamic>([
      repo.getProduct(widget.productId),
      repo.getStockForProduct(widget.productId),
      repo.getStockVariants(widget.productId),
      repo.getProductStorageAssignments(
        widget.productId,
        locationId: locationId,
      ),
      repo.getProductTransactions(widget.productId, limit: 200),
    ]);
    final product = results[0] as ProductDto;
    final stock = results[1] as InventoryListItem?;
    final variants = results[2] as List<InventoryVariantStockDto>;
    final storageAssignments = results[3] as List<ProductStorageAssignmentDto>;
    final txns = results[4] as List<ProductTransactionDto>;
    return _ProductBundle(
      product: product,
      stock: stock,
      variants: variants,
      storageAssignments: storageAssignments,
      transactions: txns,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = AppBreakpoints.isTabletOrDesktop(context);
    final localePrefs = ref.watch(localePreferencesProvider);
    return Scaffold(
      appBar: AppBar(
        leadingWidth: isWide ? 104 : null,
        leading: isWide ? const DesktopSidebarToggleLeading() : null,
        title: const Text('Transactions'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<_ProductBundle>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator(minHeight: 2);
            }
            if (snapshot.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 64),
                  AppErrorView(
                    error: snapshot.error!,
                    onRetry: _refresh,
                  ),
                ],
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: Text('No data'));
            }
            final items = data.transactions;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _ProductHeader(
                  product: data.product,
                  stock: data.stock,
                  variants: data.variants,
                  storageAssignments: data.storageAssignments,
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No transactions found'),
                  ))
                else ...[
                  for (final t in items) ...[
                    _TransactionTile(
                      t: t,
                      localePrefs: localePrefs,
                      onTap: () => _openTransaction(t),
                    ),
                    const SizedBox(height: 8),
                  ]
                ]
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({
    required this.product,
    required this.stock,
    required this.variants,
    required this.storageAssignments,
  });
  final ProductDto product;
  final InventoryListItem? stock;
  final List<InventoryVariantStockDto> variants;
  final List<ProductStorageAssignmentDto> storageAssignments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = stock?.isLowStock ?? false;
    final primaryStorage = () {
      final primary = storageAssignments.where((e) => e.isPrimary);
      if (primary.isNotEmpty) return primary.first.storageLabel;
      if (storageAssignments.isNotEmpty) {
        return storageAssignments.first.storageLabel;
      }
      return stock?.primaryStorage;
    }();
    final totalVariantQty =
        variants.fold<double>(0, (sum, item) => sum + item.quantity);
    final averageCost = () {
      if (variants.isNotEmpty && totalVariantQty > 0) {
        final weighted = variants.fold<double>(
          0,
          (sum, item) => sum + (item.quantity * item.averageCost),
        );
        return weighted / totalVariantQty;
      }
      final firstPositiveCost = variants
          .map((e) => e.averageCost)
          .where((value) => value > 0)
          .cast<double?>()
          .firstOrNull;
      return firstPositiveCost ?? product.costPrice;
    }();
    final sellingPrice = () {
      final primaryBarcode =
          product.barcodes.cast<ProductBarcodeDto?>().firstWhere(
                (item) => item?.isPrimary ?? false,
                orElse: () => null,
              );
      return primaryBarcode?.sellingPrice ?? product.sellingPrice;
    }();
    final stockValue = averageCost == null || stock == null
        ? null
        : averageCost * stock!.stock;
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (low)
                  Chip(
                    label: const Text('Low'),
                    backgroundColor: theme.colorScheme.errorContainer,
                    labelStyle: TextStyle(
                      color: theme.colorScheme.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: [
                if ((product.sku ?? '').isNotEmpty)
                  _InfoRow(
                      icon: Icons.qr_code_2_rounded,
                      label: 'SKU',
                      value: product.sku!),
                if ((stock?.categoryName ?? '').isNotEmpty)
                  _InfoRow(
                      icon: Icons.category_rounded,
                      label: 'Category',
                      value: stock!.categoryName!),
                if ((stock?.unitSymbol ?? '').isNotEmpty)
                  _InfoRow(
                      icon: Icons.straighten_rounded,
                      label: 'Unit',
                      value: stock!.unitSymbol!),
                if ((stock?.brandName ?? '').isNotEmpty)
                  _InfoRow(
                      icon: Icons.branding_watermark_rounded,
                      label: 'Brand',
                      value: stock!.brandName!),
                _InfoRow(
                  icon: Icons.route_rounded,
                  label: 'Tracking',
                  value: product.trackingType,
                ),
                if (averageCost != null)
                  _InfoRow(
                    icon: Icons.payments_outlined,
                    label: 'Avg Cost',
                    value: averageCost.toStringAsFixed(2),
                  ),
                if (sellingPrice != null)
                  _InfoRow(
                    icon: Icons.sell_outlined,
                    label: 'Sell',
                    value: sellingPrice.toStringAsFixed(2),
                  ),
                if ((primaryStorage ?? '').isNotEmpty)
                  _InfoRow(
                    icon: Icons.warehouse_outlined,
                    label: 'Storage',
                    value: primaryStorage!,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Stock: ${stock?.stock.toStringAsFixed(2) ?? '—'}',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Reorder: ${stock?.reorderLevel ?? product.reorderLevel}',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if (stockValue != null) ...[
              const SizedBox(height: 6),
              Text(
                'Stock value: ${stockValue.toStringAsFixed(2)}',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Text('$label: ',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.t,
    required this.localePrefs,
    this.onTap,
  });
  final ProductTransactionDto t;
  final LocalePreferencesState localePrefs;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuantity = t.quantity.abs() >= 0.0005;
    final hasAmount = (t.amount ?? 0).abs() >= 0.0005;
    final qtyColor = hasQuantity
        ? (t.quantity > 0 ? Colors.green : theme.colorScheme.error)
        : theme.colorScheme.onSurfaceVariant;
    final amountColor = hasAmount
        ? ((t.amount ?? 0) > 0 ? Colors.green : theme.colorScheme.error)
        : theme.colorScheme.onSurfaceVariant;
    final ts = AppDateTime.formatDateTime(
      context,
      localePrefs,
      t.occurredAt,
      fallback: '',
    );
    return ListTile(
      tileColor: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
      title: Row(
        children: [
          _TypeChip(type: t.type),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              t.reference,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            hasQuantity
                ? '${t.quantity > 0 ? '+' : '-'} ${t.quantity.abs().toStringAsFixed(3)}'
                : t.quantity.abs().toStringAsFixed(3),
            style: TextStyle(fontWeight: FontWeight.w700, color: qtyColor),
          ),
          if (hasAmount)
            Text(
              'Cost ${t.amount! > 0 ? '+' : '-'}${t.amount!.abs().toStringAsFixed(2)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ts.isNotEmpty) Text(ts),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              if ((t.locationName ?? '').isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text(t.locationName!),
                  ],
                ),
              if ((t.partnerName ?? '').isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 14),
                    const SizedBox(width: 4),
                    Text(t.partnerName!),
                  ],
                ),
              if ((t.notes ?? '').isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notes_outlined, size: 14),
                    const SizedBox(width: 4),
                    Flexible(
                        child: Text(t.notes!, overflow: TextOverflow.ellipsis)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final String type;

  Color _color(BuildContext context) {
    final theme = Theme.of(context);
    switch (type) {
      case 'PURCHASE':
      case 'SALE_RETURN':
      case 'TRANSFER_IN':
        return Colors.green.withValues(alpha: 0.15);
      case 'SALE':
      case 'PURCHASE_RETURN':
      case 'TRANSFER_OUT':
        return theme.colorScheme.errorContainer;
      case 'SUPPLIER_DEBIT_NOTE':
        return Colors.orange.withValues(alpha: 0.18);
      case 'ADJUSTMENT':
      default:
        return theme.colorScheme.surfaceContainerHighest;
    }
  }

  Color _textColor(BuildContext context) {
    final theme = Theme.of(context);
    switch (type) {
      case 'PURCHASE':
      case 'SALE_RETURN':
      case 'TRANSFER_IN':
        return Colors.green.shade800;
      case 'SALE':
      case 'PURCHASE_RETURN':
      case 'TRANSFER_OUT':
        return theme.colorScheme.onErrorContainer;
      case 'SUPPLIER_DEBIT_NOTE':
        return Colors.orange.shade900;
      case 'ADJUSTMENT':
      default:
        return theme.colorScheme.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        type.replaceAll('_', ' '),
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _textColor(context)),
      ),
    );
  }
}
