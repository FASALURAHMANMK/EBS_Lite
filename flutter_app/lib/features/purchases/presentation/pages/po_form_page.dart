import 'package:ebs_lite/features/inventory/data/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../suppliers/data/supplier_repository.dart';
import '../../../suppliers/data/models.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../data/purchases_repository.dart';

class PoFormPage extends ConsumerStatefulWidget {
  const PoFormPage({super.key});

  @override
  ConsumerState<PoFormPage> createState() => _PoFormPageState();
}

class _PoFormPageState extends ConsumerState<PoFormPage> {
  int? _supplierId;
  String? _supplierName;
  final _refNo = TextEditingController();
  final _notes = TextEditingController();
  final List<_PoLine> _lines = [_PoLine()];
  bool _saving = false;

  @override
  void dispose() {
    _refNo.dispose();
    _notes.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SupplierPicker(
              supplierId: _supplierId,
              supplierName: _supplierName,
              onPicked: (id, name) => setState(() {
                _supplierId = id;
                _supplierName = name;
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _refNo,
              decoration: const InputDecoration(
                labelText: 'Reference Number (optional)',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Text('Items', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildLines(theme),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _lines.add(_PoLine())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Item'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Create PO'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLines(ThemeData theme) {
    final widgets = <Widget>[];
    for (int i = 0; i < _lines.length; i++) {
      widgets.add(Card(
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            _LineProductPicker(line: _lines[i]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: TextField(
                controller: _lines[i].qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Quantity',
                    prefixIcon: Icon(Icons.format_list_numbered_rounded)),
              )),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                controller: _lines[i].price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                    labelText: 'Unit Price',
                    prefixIcon: Icon(Icons.currency_rupee_rounded)),
              )),
              IconButton(
                tooltip: 'Remove',
                onPressed: _lines.length == 1
                    ? null
                    : () => setState(() => _lines.removeAt(i)),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ]),
          ]),
        ),
      ));
    }
    return widgets;
  }

  Future<void> _save() async {
    final supplierId = _supplierId;
    if (supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please select supplier')));
      return;
    }
    final lines = _lines
        .where((l) =>
            l.product != null && (double.tryParse(l.qty.text.trim()) ?? 0) > 0)
        .toList();
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Add at least one item with quantity')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final items = [
        for (final l in lines)
          {
            'product_id': l.product!.productId,
            'quantity': double.tryParse(l.qty.text.trim()) ?? 0,
            'unit_price': double.tryParse(l.price.text.trim()) ?? 0,
          }
      ];
      final id = await repo.createPurchaseOrder(
        supplierId: supplierId,
        items: items,
        referenceNumber: _refNo.text.trim().isEmpty ? null : _refNo.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _PoLine {
  InventoryListItem? product;
  final qty = TextEditingController();
  final price = TextEditingController();
  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _LineProductPicker extends ConsumerStatefulWidget {
  const _LineProductPicker({required this.line});
  final _PoLine line;

  @override
  ConsumerState<_LineProductPicker> createState() => _LineProductPickerState();
}

class _LineProductPickerState extends ConsumerState<_LineProductPicker> {
  @override
  Widget build(BuildContext context) {
    final p = widget.line.product;
    return InkWell(
      onTap: () async {
        final picked = await _openProductPicker(context);
        if (picked != null) setState(() => widget.line.product = picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Product',
          prefixIcon: Icon(Icons.inventory_2_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(children: [
          Expanded(
              child: Text(
                  p == null
                      ? 'Tap to select a product'
                      : '${p.name}${(p.sku ?? '').isNotEmpty ? ' • SKU: ${p.sku}' : ''}',
                  overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down_rounded),
        ]),
      ),
    );
  }

  Future<InventoryListItem?> _openProductPicker(BuildContext context) async {
    final repo = ref.read(inventoryRepositoryProvider);
    List<InventoryListItem> initial = [];
    try {
      initial = await repo.getStock();
    } catch (_) {}
    List<InventoryListItem> results = List.of(initial);
    int? selectedId = widget.line.product?.productId;
    return showDialog<InventoryListItem?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Product'),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                      hintText: 'Search by name or SKU',
                      prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) async {
                    final q = v.trim();
                    if (q.isEmpty) {
                      setInner(() => results = List.of(initial));
                      return;
                    }
                    final list = await repo.searchProducts(q);
                    setInner(() => results = list);
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: results.isEmpty
                      ? const Center(child: Text('No products'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final it = results[i];
                            return RadioListTile<int>(
                              value: it.productId,
                              groupValue: selectedId,
                              onChanged: (v) => setInner(() => selectedId = v),
                              title: Text(it.name),
                              subtitle: Text([
                                if ((it.sku ?? '').isNotEmpty) 'SKU: ${it.sku}',
                                'Stock: ${it.stock.toStringAsFixed(2)}'
                              ].join(' • ')),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final it = results.firstWhere(
                    (e) => e.productId == selectedId,
                    orElse: () => InventoryListItem(
                        productId: -1,
                        name: '',
                        sku: null,
                        categoryName: null,
                        brandName: null,
                        unitSymbol: null,
                        reorderLevel: 0,
                        stock: 0,
                        isLowStock: false,
                        price: null),
                  );
                  Navigator.pop(context, it.productId == -1 ? null : it);
                },
                child: const Text('Select')),
          ],
        ),
      ),
    );
  }
}

class _SupplierPicker extends ConsumerWidget {
  const _SupplierPicker(
      {this.supplierId, this.supplierName, required this.onPicked});
  final int? supplierId;
  final String? supplierName;
  final void Function(int id, String name) onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = supplierName ??
        (supplierId == null
            ? 'Tap to select supplier'
            : 'Supplier #$supplierId');
    return InkWell(
      onTap: () async {
        final picked = await _openSupplierPicker(context, ref);
        if (picked != null) onPicked(picked.$1, picked.$2);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
            labelText: 'Supplier',
            prefixIcon: Icon(Icons.local_shipping_outlined),
            border: OutlineInputBorder()),
        child: Row(children: [
          Expanded(child: Text(display, overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down_rounded)
        ]),
      ),
    );
  }

  Future<(int, String)?> _openSupplierPicker(
      BuildContext context, WidgetRef ref) async {
    final repo = ref.read(supplierRepositoryProvider);
    List<SupplierDto> results = [];
    try {
      results = await repo.getSuppliers();
    } catch (_) {}
    String q = '';
    int? selected;
    return showDialog<(int, String)?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Supplier'),
          content: SizedBox(
            width: 720,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(
                      hintText: 'Search suppliers',
                      prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) async {
                    q = v.trim();
                    final list =
                        await repo.getSuppliers(search: q.isEmpty ? null : q);
                    setInner(() => results = list);
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: results.isEmpty
                      ? const Center(child: Text('No suppliers'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final s = results[i];
                            return RadioListTile<int>(
                              value: s.supplierId,
                              groupValue: selected,
                              onChanged: (v) => setInner(() => selected = v),
                              title: Text(s.name),
                              subtitle: Text([(s.phone ?? ''), (s.email ?? '')]
                                  .where((e) => e.isNotEmpty)
                                  .join(' • ')),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  final s = results.firstWhere((e) => e.supplierId == selected,
                      orElse: () => results.isEmpty
                          ? SupplierDto(
                              supplierId: -1,
                              name: '',
                              contactPerson: null,
                              phone: null,
                              email: null,
                              address: null,
                              paymentTerms: 0,
                              creditLimit: 0,
                              isActive: true,
                              totalPurchases: 0,
                              totalReturns: 0,
                              outstandingAmount: 0,
                              lastPurchaseDate: null)
                          : results.first);
                  if (s.supplierId <= 0) {
                    Navigator.pop(context, null);
                    return;
                  }
                  Navigator.pop(context, (s.supplierId, s.name));
                },
                child: const Text('Select')),
          ],
        ),
      ),
    );
  }
}
