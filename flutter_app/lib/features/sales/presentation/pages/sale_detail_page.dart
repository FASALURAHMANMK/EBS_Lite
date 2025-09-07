import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pos/data/pos_repository.dart';
import '../../../pos/data/models.dart';

class SaleDetailPage extends ConsumerStatefulWidget {
  const SaleDetailPage({super.key, required this.saleId});
  final int saleId;

  @override
  ConsumerState<SaleDetailPage> createState() => _SaleDetailPageState();
}

class _SaleDetailPageState extends ConsumerState<SaleDetailPage> {
  SaleDto? _sale;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(posRepositoryProvider);
      final s = await repo.getSaleById(widget.saleId);
      if (!mounted) return;
      setState(() => _sale = s);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _sale;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s?.saleNumber.isNotEmpty == true ? s!.saleNumber : 'Sale #${widget.saleId}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (s != null) ...[
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.point_of_sale_rounded),
                  title: Text(s.saleNumber),
                  subtitle: Text([
                    if ((s.customerName ?? '').isNotEmpty) s.customerName!,
                  ].where((e) => e.isNotEmpty).join(' · ')),
                  trailing: Text(s.totalAmount.toStringAsFixed(2), style: theme.textTheme.titleMedium),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                child: Column(children: [
                  const ListTile(title: Text('Items')),
                  const Divider(height: 1),
                  for (final it in s.items)
                    ListTile(
                      leading: const Icon(Icons.inventory_2_rounded),
                      title: Text(it.productName ?? (it.productId != null ? 'Product #${it.productId}' : 'Item')),
                      subtitle: Text('Qty: ${it.quantity.toStringAsFixed(2)} × ${it.unitPrice.toStringAsFixed(2)}'),
                      trailing: Text(((it.quantity * it.unitPrice) * (1 - (it.discountPercent / 100))).toStringAsFixed(2),
                          style: theme.textTheme.bodyLarge),
                    ),
                ]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

