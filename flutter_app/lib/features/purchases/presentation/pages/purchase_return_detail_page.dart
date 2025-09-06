import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/purchase_returns_repository.dart';

class PurchaseReturnDetailPage extends ConsumerStatefulWidget {
  const PurchaseReturnDetailPage({super.key, required this.returnId});
  final int returnId;
  @override
  ConsumerState<PurchaseReturnDetailPage> createState() => _PurchaseReturnDetailPageState();
}

class _PurchaseReturnDetailPageState extends ConsumerState<PurchaseReturnDetailPage> {
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
      final doc = await ref.read(purchaseReturnsRepositoryProvider).getReturn(widget.returnId);
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
      appBar: AppBar(title: Text(d?['return_number']?.toString() ?? 'Purchase Return')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Card(
              elevation: 0,
              child: ListTile(
                title: Text(d?['purchase']?['purchase_number']?.toString() ?? ''),
                subtitle: Text([
                  if ((d?['supplier']?['name'] ?? '') != '') (d?['supplier']?['name']).toString(),
                  if (d?['return_date'] != null) (d?['return_date']).toString(),
                ].where((e) => e.isNotEmpty).join(' · ')),
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
                    trailing: Text(((it['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2), style: theme.textTheme.titleMedium),
                  ),
              ]),
            )
          ],
        ),
      ),
    );
  }
}

