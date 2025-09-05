import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/grn_repository.dart';
import '../../data/purchases_repository.dart';
import '../../data/models.dart';
import 'grn_form_page.dart';
import 'grn_detail_page.dart';
import 'purchase_orders_page.dart';

class GoodsReceiptsPage extends ConsumerStatefulWidget {
  const GoodsReceiptsPage({super.key});

  @override
  ConsumerState<GoodsReceiptsPage> createState() => _GoodsReceiptsPageState();
}

class _GoodsReceiptsPageState extends ConsumerState<GoodsReceiptsPage> {
  final _search = TextEditingController();
  bool _loading = true;
  List<GoodsReceiptDto> _list = const [];

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
    setState(() => _loading = true);
    try {
      final repo = ref.read(grnRepositoryProvider);
      final list = await repo.getGoodsReceipts(search: _search.text.trim().isEmpty ? null : _search.text.trim());
      if (!mounted) return;
      setState(() => _list = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _list
        : _list.where((gr) => gr.receiptNumber.toLowerCase().contains(q) || (gr.supplierName ?? '').toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Goods Receipt Notes'),
        actions: [
          IconButton(
            tooltip: 'Create',
            icon: const Icon(Icons.add_rounded),
            onPressed: _openCreateDialog,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by GRN # or supplier',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                    onPressed: _load,
                  ),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : (filtered.isEmpty
                      ? const Center(child: Text('No goods receipts'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final gr = filtered[i];
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: const Icon(Icons.receipt_long_rounded),
                                title: Text(gr.receiptNumber),
                                subtitle: Text([
                                  if ((gr.supplierName ?? '').isNotEmpty) gr.supplierName!,
                                  _fmt(gr.receivedDate),
                                ].join(' • ')),
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => GoodsReceiptDetailPage(goodsReceiptId: gr.goodsReceiptId)),
                                  );
                                },
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Goods Receipt'),
        content: const Text('Choose entry type:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, 'po'), child: const Text('With PO')),
          FilledButton(onPressed: () => Navigator.pop(context, 'no_po'), child: const Text('Without PO')),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'po') {
      // Pick a pending PO and receive
      final picked = await _pickPO();
      if (picked != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => _ReceiveAgainstPoPage(purchaseId: picked)),
        );
        if (!mounted) return;
        _load();
      } else {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PurchaseOrdersPage()),
        );
      }
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GrnFormPage()),
    );
    if (created == true) _load();
  }

  Future<int?> _pickPO() async {
    final repo = ref.read(purchasesRepositoryProvider);
    List<Map<String, dynamic>> list = [];
    try { list = await repo.getPendingOrders(); } catch (_) {}
    int? selected;
    return showDialog<int?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Purchase Order'),
          content: SizedBox(
            width: 720,
            child: list.isEmpty
                ? const Text('No pending/partial orders')
                : SizedBox(
                    height: 360,
                    child: ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final it = list[i];
                        return RadioListTile<int>(
                          value: it['purchase_id'] as int,
                          groupValue: selected,
                          onChanged: (v) => setInner(() => selected = v),
                          title: Text(it['purchase_number']?.toString() ?? ''),
                          subtitle: Text((it['supplier']?['name'] ?? it['supplier_name'] ?? '').toString()),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, selected), child: const Text('Select')),
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
  return '$y-$m-$d';
}

class _ReceiveAgainstPoPage extends ConsumerStatefulWidget {
  const _ReceiveAgainstPoPage({required this.purchaseId});
  final int purchaseId;
  @override
  ConsumerState<_ReceiveAgainstPoPage> createState() => _ReceiveAgainstPoPageState();
}

class _ReceiveAgainstPoPageState extends ConsumerState<_ReceiveAgainstPoPage> {
  Map<String, dynamic>? _po;
  bool _loading = true;
  final List<TextEditingController> _qty = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _qty) { c.dispose(); }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final po = await repo.getPurchase(widget.purchaseId);
      if (!mounted) return;
      _qty.clear();
      final items = (po['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      for (final it in items) {
        final qty = ((it['quantity'] as num?)?.toDouble() ?? 0) - ((it['received_quantity'] as num?)?.toDouble() ?? 0);
        _qty.add(TextEditingController(text: qty > 0 ? qty.toStringAsFixed(2) : '0'));
      }
      setState(() => _po = po);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final po = _po;
    final items = (po?['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    return Scaffold(
      appBar: AppBar(title: Text('Receive ${po?['purchase_number'] ?? ''}')),
      body: SafeArea(
        child: _loading
            ? const LinearProgressIndicator(minHeight: 2)
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (int i = 0; i < items.length; i++)
                    Card(
                      elevation: 0,
                      child: ListTile(
                        title: Text(items[i]['product']?['name']?.toString() ?? 'Product #${items[i]['product_id']}'),
                        subtitle: Text('Remaining: ${(((items[i]['quantity'] as num?)?.toDouble() ?? 0) - ((items[i]['received_quantity'] as num?)?.toDouble() ?? 0)).toStringAsFixed(2)}'),
                        trailing: SizedBox(
                          width: 120,
                          child: TextField(controller: _qty[i], keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Receive')),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 48,
                    child: FilledButton(
                      onPressed: _receive,
                      child: const Text('Record GRN'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _receive() async {
    final po = _po;
    if (po == null) return;
    final items = (po['items'] as List? ?? const []).cast<Map<String, dynamic>>();
    final payload = <Map<String, dynamic>>[];
    for (int i = 0; i < items.length; i++) {
      final rem = ((items[i]['quantity'] as num?)?.toDouble() ?? 0) - ((items[i]['received_quantity'] as num?)?.toDouble() ?? 0);
      final val = double.tryParse(_qty[i].text.trim()) ?? 0;
      if (val > 0) {
        final take = val > rem ? rem : val;
        payload.add({'purchase_detail_id': items[i]['purchase_detail_id'] as int, 'received_quantity': take});
      }
    }
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('Enter quantities to receive')));
      return;
    }
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      await repo.receiveAgainstPO(purchaseId: widget.purchaseId, items: payload);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(const SnackBar(content: Text('GRN recorded')));
    } catch (e) {
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
