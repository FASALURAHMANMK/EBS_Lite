import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/grn_repository.dart';
import '../../data/models.dart';

class GoodsReceiptDetailPage extends ConsumerStatefulWidget {
  const GoodsReceiptDetailPage({super.key, required this.goodsReceiptId});
  final int goodsReceiptId;

  @override
  ConsumerState<GoodsReceiptDetailPage> createState() => _GoodsReceiptDetailPageState();
}

class _GoodsReceiptDetailPageState extends ConsumerState<GoodsReceiptDetailPage> {
  GoodsReceiptDetailDto? _detail;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(grnRepositoryProvider);
      final d = await repo.getGoodsReceipt(widget.goodsReceiptId);
      if (!mounted) return;
      setState(() => _detail = d);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to load GRN: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      appBar: AppBar(title: Text(d?.receiptNumber ?? 'Goods Receipt')),
      body: SafeArea(
        child: _loading
            ? const LinearProgressIndicator(minHeight: 2)
            : d == null
                ? const Center(child: Text('Not found'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Header(detail: d),
                      const SizedBox(height: 12),
                      _Items(items: d.items),
                    ],
                  ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail});
  final GoodsReceiptDetailDto detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(detail.receiptNumber, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text([
              if ((detail.supplierName ?? '').isNotEmpty) 'Supplier: ${detail.supplierName}',
              'Date: ${_fmt(detail.receivedDate)}',
            ].join(' • '), style: theme.textTheme.bodyMedium),
            if (detail.purchaseId != null) ...[
              const SizedBox(height: 4),
              Text('Purchase ID: ${detail.purchaseId}', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.items});
  final List<GoodsReceiptItemDto> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(12), child: Text('No items')));
    }
    return Card(
      elevation: 0,
      child: Column(
        children: [
          for (final it in items)
            ListTile(
              leading: const Icon(Icons.inventory_2_rounded),
              title: Text(it.productName ?? 'Product #${it.productId}'),
              subtitle: Text([
                if ((it.sku ?? '').isNotEmpty) 'SKU: ${it.sku}',
                'Qty: ${it.receivedQuantity.toStringAsFixed(2)}',
                'Rate: ${it.unitPrice.toStringAsFixed(2)}',
              ].join(' • ')),
              trailing: Text(it.lineTotal.toStringAsFixed(2), style: theme.textTheme.titleMedium),
            ),
        ],
      ),
    );
  }
}

String _fmt(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

