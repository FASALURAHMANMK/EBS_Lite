import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';

class StockAdjustmentDocumentDetailPage extends ConsumerStatefulWidget {
  const StockAdjustmentDocumentDetailPage({super.key, required this.documentId});
  final int documentId;

  @override
  ConsumerState<StockAdjustmentDocumentDetailPage> createState() => _StockAdjustmentDocumentDetailPageState();
}

class _StockAdjustmentDocumentDetailPageState extends ConsumerState<StockAdjustmentDocumentDetailPage> {
  StockAdjustmentDocumentDto? _doc;
  Map<int, ProductDto> _products = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final doc = await repo.getStockAdjustmentDocument(widget.documentId);
      final ids = doc.items.map((e) => e.productId).toSet().toList();
      final map = <int, ProductDto>{};
      for (final id in ids) {
        try {
          final p = await repo.getProduct(id);
          map[id] = p;
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _products = map;
        _doc = doc;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = _doc;
    return Scaffold(
      appBar: AppBar(title: Text(d?.documentNumber ?? 'Document')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(d?.reason ?? '-', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(d?.createdAt != null ? _fmt(d!.createdAt!) : '',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (d != null)
              ...d.items.map((a) {
                final name = _products[a.productId]?.name ?? 'Product #${a.productId}';
                final qty = a.adjustment;
                final color = qty >= 0 ? Colors.green : theme.colorScheme.error;
                return Card(
                  elevation: 0,
                  child: ListTile(
                    title: Text(name),
                    trailing: Text((qty >= 0 ? '+ ' : '') + qty.toStringAsFixed(2),
                        style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

String _fmt(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}

