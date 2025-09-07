import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/sales_repository.dart';

class SaleReturnDetailPage extends ConsumerStatefulWidget {
  const SaleReturnDetailPage({super.key, required this.returnId});
  final int returnId;

  @override
  ConsumerState<SaleReturnDetailPage> createState() => _SaleReturnDetailPageState();
}

class _SaleReturnDetailPageState extends ConsumerState<SaleReturnDetailPage> {
  Map<String, dynamic>? _doc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(salesRepositoryProvider);
      final doc = await repo.getSaleReturn(widget.returnId);
      if (!mounted) return;
      setState(() => _doc = doc);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    final items = (d?['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(d?['return_number']?.toString() ?? 'Sale Return')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Card(
              elevation: 0,
              child: ListTile(
                leading: const Icon(Icons.assignment_return_rounded),
                title: Text(
                  (d?['sale']?['sale_number']?.toString()) ??
                      (d?['sale_id'] != null ? 'Sale #${d?['sale_id']}' : ''),
                ),
                subtitle: Text([
                  if ((d?['customer']?['name'] ?? '') != '')
                    (d?['customer']?['name']).toString()
                  else if (d?['customer_id'] != null)
                    'Customer #${d?['customer_id']}',
                  if (d?['return_date'] != null) (d?['return_date']).toString(),
                ].where((e) => e.isNotEmpty).join(' · ')),
                trailing: Text(((d?['total_amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                    style: theme.textTheme.titleMedium),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              child: Column(children: [
                const ListTile(title: Text('Items')),
                const Divider(height: 1),
                for (final it in items)
                  ListTile(
                    leading: const Icon(Icons.inventory_2_rounded),
                    title: Text(it['product']?['name']?.toString() ?? 'Product #${it['product_id']}'),
                    subtitle: Text('Qty: ${((it['quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}'),
                    trailing: Text(((it['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
                        style: theme.textTheme.titleMedium),
                  ),
              ]),
            )
          ],
        ),
      ),
    );
  }
}
