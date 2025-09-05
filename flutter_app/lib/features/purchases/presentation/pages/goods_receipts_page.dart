import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/grn_repository.dart';
import '../../data/models.dart';
import 'grn_form_page.dart';

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
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('With PO flow coming soon')));
      return;
    }
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const GrnFormPage()),
    );
    if (created == true) _load();
  }
}

String _fmt(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
