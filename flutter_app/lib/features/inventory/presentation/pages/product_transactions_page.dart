import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../../../purchases/presentation/pages/grn_detail_page.dart';
import '../../../purchases/presentation/pages/purchase_return_detail_page.dart';
import 'stock_transfer_view_page.dart';
import 'stock_adjustments_page.dart';
import 'stock_adjustment_document_detail_page.dart';

class ProductTransactionsPage extends ConsumerStatefulWidget {
  const ProductTransactionsPage({super.key, required this.productId, required this.productName});
  final int productId;
  final String productName; // kept for backward compatibility (not shown in header)

  @override
  ConsumerState<ProductTransactionsPage> createState() => _ProductTransactionsPageState();
}

class _ProductBundle {
  final ProductDto product;
  final InventoryListItem? stock;
  final List<ProductTransactionDto> transactions;
  _ProductBundle({required this.product, required this.stock, required this.transactions});
}

class _ProductTransactionsPageState extends ConsumerState<ProductTransactionsPage> {
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
          MaterialPageRoute(builder: (_) => GoodsReceiptDetailPage(goodsReceiptId: t.entityId)),
        );
        break;
      case 'transfer':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StockTransferViewPage(transferId: t.entityId)),
        );
        break;
      case 'purchase_return':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PurchaseReturnDetailPage(returnId: t.entityId)),
        );
        break;
      case 'stock_adjustment_document':
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StockAdjustmentDocumentDetailPage(documentId: t.entityId)),
        );
        break;
      case 'stock_adjustment':
        if (!mounted) return;
        // No direct detail view for single adjustments; open documents page for context.
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StockAdjustmentsPage()),
        );
        break;
      // Future: add sale/sale_return/purchase_return when detail pages exist
      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Detail view not available for this transaction')));
    }
  }

  Future<_ProductBundle> _load() async {
    final repo = ref.read(inventoryRepositoryProvider);
    final results = await Future.wait<dynamic>([
      repo.getProduct(widget.productId),
      repo.getStockForProduct(widget.productId),
      repo.getProductTransactions(widget.productId, limit: 200),
    ]);
    final product = results[0] as ProductDto;
    final stock = results[1] as InventoryListItem?;
    final txns = results[2] as List<ProductTransactionDto>;
    return _ProductBundle(product: product, stock: stock, transactions: txns);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
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
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Failed to load: ${snapshot.error}',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
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
                _ProductHeader(product: data.product, stock: data.stock),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text('No transactions found'),
                  ))
                else ...[
                  for (final t in items) ...[
                    _TransactionTile(t: t, onTap: () => _openTransaction(t)),
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
  const _ProductHeader({required this.product, required this.stock});
  final ProductDto product;
  final InventoryListItem? stock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final low = stock?.isLowStock ?? false;
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
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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
                  _InfoRow(icon: Icons.qr_code_2_rounded, label: 'SKU', value: product.sku!),
                if ((stock?.categoryName ?? '').isNotEmpty)
                  _InfoRow(icon: Icons.category_rounded, label: 'Category', value: stock!.categoryName!),
                if ((stock?.unitSymbol ?? '').isNotEmpty)
                  _InfoRow(icon: Icons.straighten_rounded, label: 'Unit', value: stock!.unitSymbol!),
                if ((stock?.brandName ?? '').isNotEmpty)
                  _InfoRow(icon: Icons.branding_watermark_rounded, label: 'Brand', value: stock!.brandName!),
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
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value});
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
        Text('$label: ', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        Text(value, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.t, this.onTap});
  final ProductTransactionDto t;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qtyColor = t.quantity >= 0 ? Colors.green : theme.colorScheme.error;
    final ts = t.occurredAt != null ? '${t.occurredAt!.toLocal()}' : '';
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
          const SizedBox(width: 8),
          Text(
            (t.quantity >= 0 ? '+ ' : '− ') + t.quantity.abs().toStringAsFixed(3),
            style: TextStyle(fontWeight: FontWeight.w700, color: qtyColor),
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
                    Flexible(child: Text(t.notes!, overflow: TextOverflow.ellipsis)),
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
        return Colors.green.withOpacity(0.15);
      case 'SALE':
      case 'PURCHASE_RETURN':
      case 'TRANSFER_OUT':
        return theme.colorScheme.errorContainer;
      case 'ADJUSTMENT':
      default:
        return theme.colorScheme.surfaceVariant;
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textColor(context)),
      ),
    );
  }
}
