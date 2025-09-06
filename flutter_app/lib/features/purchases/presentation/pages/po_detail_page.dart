import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/purchases_repository.dart';

class PoDetailPage extends ConsumerStatefulWidget {
  const PoDetailPage({super.key, required this.purchaseId});
  final int purchaseId;

  @override
  ConsumerState<PoDetailPage> createState() => _PoDetailPageState();
}

class _PoDetailPageState extends ConsumerState<PoDetailPage> {
  Map<String, dynamic>? _po;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final po = await repo.getPurchase(widget.purchaseId);
      if (!mounted) return;
      setState(() => _po = po);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final po = _po;
    final status = (po?['status'] ?? '').toString();
    final items = (po?['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final hasRemaining = items.any((it) {
      final qty = (it['quantity'] as num?)?.toDouble() ?? 0;
      final rec = (it['received_quantity'] as num?)?.toDouble() ?? 0;
      return qty - rec > 0.000001;
    });
    final canApprove = !_loading && (status != 'APPROVED' && status != 'PARTIALLY_RECEIVED' && status != 'RECEIVED');
    final canReceive = !_loading && hasRemaining && (status == 'APPROVED' || status == 'PARTIALLY_RECEIVED');

    return Scaffold(
      appBar: AppBar(title: Text(po?['purchase_number']?.toString() ?? 'Purchase Order')),
      body: SafeArea(
        child: _loading
            ? const LinearProgressIndicator(minHeight: 2)
            : po == null
                ? const Center(child: Text('Not found'))
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _Header(po: po),
                      const SizedBox(height: 12),
                      _Items(po: po),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(
                          onPressed: canApprove ? _approve : null,
                          icon: const Icon(Icons.verified_outlined),
                          label: Text(status == 'APPROVED' || status == 'PARTIALLY_RECEIVED' || status == 'RECEIVED' ? 'Approved' : 'Approve'),
                        )),
                        const SizedBox(width: 8),
                        Expanded(child: FilledButton.icon(
                          onPressed: canReceive ? _receive : null,
                          icon: const Icon(Icons.call_received_rounded),
                          label: Text(status == 'RECEIVED' ? 'Received' : 'Receive'),
                        )),
                      ]),
                    ],
                  ),
      ),
    );
  }

  Future<void> _approve() async {
    try {
      setState(() => _loading = true);
      final repo = ref.read(purchasesRepositoryProvider);
      await repo.approvePurchaseOrder(widget.purchaseId);
      await _load();
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('Approve failed: $e')));
    }
  }

  Future<void> _receive() async {
    final po = _po;
    if (po == null) return;
    final status = (po['status'] ?? '').toString();
    if (status != 'APPROVED' && status != 'PARTIALLY_RECEIVED') {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Approve the PO before receiving')));
      return;
    }
    final items = (po['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final remaining = items.map((it) {
      final qty = (it['quantity'] as num?)?.toDouble() ?? 0;
      final rec = (it['received_quantity'] as num?)?.toDouble() ?? 0;
      final left = (qty - rec);
      return {
        'purchase_detail_id': it['purchase_detail_id'] as int,
        'product_name': it['product']?['name']?.toString() ?? 'Product #${it['product_id']}',
        'remaining': left > 0 ? left : 0,
      };
    }).where((e) => (e['remaining'] as double) > 0).toList();
    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Nothing to receive')));
      return;
    }
    final payload = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _ReceiveDialog(lines: remaining),
    );
    if (payload == null || payload.isEmpty) return;
    try {
      setState(() => _loading = true);
      final repo = ref.read(purchasesRepositoryProvider);
      await repo.receiveAgainstPO(purchaseId: widget.purchaseId, items: payload);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Received successfully')));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('Receive failed: $e')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.po});
  final Map<String, dynamic> po;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(po['purchase_number']?.toString() ?? '', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text([
            if ((po['supplier']?['name'] ?? '') != '') 'Supplier: ${po['supplier']['name']}',
            if (po['status'] != null) 'Status: ${po['status']}',
          ].where((e) => e.isNotEmpty).join(' • ')),
        ]),
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.po});
  final Map<String, dynamic> po;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = (po['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    if (items.isEmpty) return const Card(elevation: 0, child: Padding(padding: EdgeInsets.all(12), child: Text('No items')));
    return Card(
      elevation: 0,
      child: Column(children: [
        for (final it in items)
          ListTile(
            leading: const Icon(Icons.inventory_2_rounded),
            title: Text(it['product']?['name']?.toString() ?? 'Product #${it['product_id']}'),
            subtitle: Text([
              'Ordered: ${((it['quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
              'Received: ${((it['received_quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
            ].join(' • ')),
            trailing: Text(((it['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2), style: theme.textTheme.titleMedium),
          ),
      ]),
    );
  }
}

class _ReceiveDialog extends StatefulWidget {
  const _ReceiveDialog({required this.lines});
  final List<Map<String, dynamic>> lines; // {purchase_detail_id, product_name, remaining}

  @override
  State<_ReceiveDialog> createState() => _ReceiveDialogState();
}

class _ReceiveDialogState extends State<_ReceiveDialog> {
  late List<TextEditingController> _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.lines.map((e) => TextEditingController(text: (e['remaining'] as double).toStringAsFixed(2))).toList();
  }

  @override
  void dispose() {
    for (final c in _qty) { c.dispose(); }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Receive Items'),
      content: SizedBox(
        width: 720,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.lines.length,
          itemBuilder: (context, i) {
            final it = widget.lines[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(child: Text(it['product_name'] as String)),
                const SizedBox(width: 8),
                SizedBox(width: 140, child: TextField(controller: _qty[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Receive Qty'))),
              ]),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () {
          final items = <Map<String, dynamic>>[];
          for (int i = 0; i < widget.lines.length; i++) {
            final qty = double.tryParse(_qty[i].text.trim()) ?? 0;
            if (qty > 0) {
              items.add({'purchase_detail_id': widget.lines[i]['purchase_detail_id'] as int, 'received_quantity': qty});
            }
          }
          Navigator.pop(context, items);
        }, child: const Text('Receive'))
      ],
    );
  }
}

