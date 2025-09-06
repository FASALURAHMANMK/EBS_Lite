import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/purchases_repository.dart';
import '../../../suppliers/data/models.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import 'po_form_page.dart';
import 'po_detail_page.dart';

class PurchaseOrdersPage extends ConsumerStatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  ConsumerState<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends ConsumerState<PurchaseOrdersPage> {
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _all = const [];
  // Filter: 'pending' | 'all' | 'received'
  String _filter = 'pending';

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
      final repo = ref.read(purchasesRepositoryProvider);
      List<Map<String, dynamic>> list;
      switch (_filter) {
        case 'received':
          list = await repo.getOrders(status: 'RECEIVED');
          break;
        case 'unapproved':
          list = await repo.getOrders(status: 'PENDING');
          break;
        case 'all':
          list = await repo.getOrders();
          break;
        case 'pending':
        default:
          list = await repo.getPendingOrders();
      }
      if (!mounted) return;
      setState(() => _all = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? _all
        : _all.where((e) => (e['purchase_number'] ?? '').toString().toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
        actions: [
          IconButton(
            tooltip: 'New PO',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final id = await Navigator.of(context).push<int>(
                MaterialPageRoute(builder: (_) => const PoFormPage()),
              );
              if (id != null) {
                await _load();
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PoDetailPage(purchaseId: id)),
                );
              }
            },
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
                decoration: InputDecoration(
                  hintText: 'Search by PO number',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: _FilterChips(
                value: _filter,
                onChanged: (v) {
                  if (_filter != v) {
                    setState(() => _filter = v);
                    _load();
                  }
                },
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : (filtered.isEmpty
                      ? const Center(child: Text('No purchase orders'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final po = filtered[i];
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                leading: const Icon(Icons.description_rounded),
                                title: Text(po['purchase_number']?.toString() ?? ''),
                                subtitle: Text([
                                  if ((po['supplier']?['name'] ?? po['supplier_name'] ?? '') != '') (po['supplier']?['name'] ?? po['supplier_name']).toString(),
                                  if (po['purchase_date'] != null) po['purchase_date'].toString(),
                                  if ((po['status'] ?? '') != '') 'Status: ${po['status']}',
                                ].where((e) => e.isNotEmpty).join(' • ')),
                                onTap: () async {
                                  final id = po['purchase_id'] as int?;
                                  if (id != null) {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(builder: (_) => PoDetailPage(purchaseId: id)),
                                    );
                                    _load();
                                  }
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
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.value, required this.onChanged});
  final String value;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final items = const <(String, String)>[
      ('pending', 'Pending & Partial'),
      ('unapproved', 'Unapproved'),
      ('received', 'Received'),
      ('all', 'All'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final it in items)
          ChoiceChip(
            label: Text(it.$2),
            selected: value == it.$1,
            onSelected: (sel) => sel ? onChanged(it.$1) : null,
          ),
      ],
    );
  }
}
