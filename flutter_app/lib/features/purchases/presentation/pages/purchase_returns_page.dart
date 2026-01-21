import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/purchase_returns_repository.dart';
import '../../data/purchases_repository.dart';
import 'purchase_return_detail_page.dart';

// Product picking (inventory)
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';

// Supplier picking
import '../../../suppliers/data/supplier_repository.dart';
import '../../../suppliers/data/models.dart';

class PurchaseReturnsPage extends ConsumerStatefulWidget {
  const PurchaseReturnsPage({super.key});

  @override
  ConsumerState<PurchaseReturnsPage> createState() =>
      _PurchaseReturnsPageState();
}

class _PurchaseReturnsPageState extends ConsumerState<PurchaseReturnsPage> {
  final _search = TextEditingController();
  bool _loading = true;
  List<Map<String, dynamic>> _all = const [];

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
      final repo = ref.read(purchaseReturnsRepositoryProvider);
      final list = await repo.getReturns();
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
        : _all
            .where((e) =>
                (e['return_number'] ?? '').toString().toLowerCase().contains(q))
            .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Returns'),
        actions: [
          IconButton(
            tooltip: 'New Return',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final id = await Navigator.of(context).push<int>(
                MaterialPageRoute(builder: (_) => const _ReturnFormPage()),
              );
              if (id != null) {
                await _load();
                if (!mounted) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => PurchaseReturnDetailPage(returnId: id)),
                );
              }
            },
          ),
          const SizedBox(width: 4)
        ],
      ),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Search by Return #',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.refresh_rounded), onPressed: _load),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? const SizedBox.shrink()
                : (filtered.isEmpty
                    ? const Center(child: Text('No purchase returns'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final pr = filtered[i];
                          return Card(
                            elevation: 0,
                            child: ListTile(
                              leading:
                                  const Icon(Icons.assignment_return_rounded),
                              title:
                                  Text(pr['return_number']?.toString() ?? ''),
                              subtitle: Text([
                                if ((pr['supplier']?['name'] ??
                                        pr['supplier_name'] ??
                                        '') !=
                                    '')
                                  (pr['supplier']?['name'] ??
                                          pr['supplier_name'])
                                      .toString(),
                                if (pr['return_date'] != null)
                                  pr['return_date'].toString(),
                                if ((pr['purchase']?['purchase_number'] ??
                                        '') !=
                                    '')
                                  'From: ${pr['purchase']['purchase_number']}',
                              ].where((e) => e.isNotEmpty).join(' · ')),
                              onTap: () async {
                                final id = pr['return_id'] as int?;
                                if (id != null) {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            PurchaseReturnDetailPage(
                                                returnId: id)),
                                  );
                                  _load();
                                }
                              },
                            ),
                          );
                        },
                      )),
          )
        ]),
      ),
    );
  }
}

class _ReturnFormPage extends ConsumerStatefulWidget {
  const _ReturnFormPage();
  @override
  ConsumerState<_ReturnFormPage> createState() => _ReturnFormPageState();
}

class _ReturnFormPageState extends ConsumerState<_ReturnFormPage> {
  int? _supplierId;
  String? _supplierName;
  int? _linkedPurchaseId; // auto-linked for backend requirement
  Map<String, dynamic>? _linkedPurchase;
  bool _loadingLink = false;
  final _reason = TextEditingController();
  final _receiptNumber = TextEditingController();
  String? _receiptFilePath;
  final List<_RetLine> _lines = [
    _RetLine(),
  ];

  @override
  void dispose() {
    _reason.dispose();
    _receiptNumber.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _linkPurchaseForSupplier() async {
    final supplierId = _supplierId;
    if (supplierId == null) return;
    setState(() {
      _loadingLink = true;
      _linkedPurchase = null;
      _linkedPurchaseId = null;
    });
    try {
      final repo = ref.read(purchasesRepositoryProvider);
      final listRec =
          await repo.getOrders(status: 'RECEIVED', supplierId: supplierId);
      final listPar = await repo.getOrders(
          status: 'PARTIALLY_RECEIVED', supplierId: supplierId);
      final list = [...listRec, ...listPar];
      if (list.isEmpty) return;
      // pick the latest by purchase_date
      list.sort((a, b) {
        final da = DateTime.tryParse((a['purchase_date'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final db = DateTime.tryParse((b['purchase_date'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });
      final id = list.first['purchase_id'] as int?;
      if (id != null) {
        final po = await repo.getPurchase(id);
        if (!mounted) return;
        setState(() {
          _linkedPurchaseId = id;
          _linkedPurchase = po;
        });
      }
    } finally {
      if (mounted)
        setState(() {
          _loadingLink = false;
        });
    }
  }

  Future<void> _pickReceiptFile() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (res != null && res.files.single.path != null) {
      setState(() => _receiptFilePath = res.files.single.path);
    }
  }

  Future<void> _save() async {
    final supplierId = _supplierId;
    if (supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Select supplier')));
      return;
    }
    // Build lines payload
    final payload = <Map<String, dynamic>>[];
    for (final l in _lines) {
      if (l.product == null) continue;
      final qty = double.tryParse(l.qty.text.trim()) ?? 0;
      if (qty <= 0) continue;
      final price = double.tryParse(l.price.text.trim()) ?? 0;
      payload.add({
        'product_id': l.product!.productId,
        'quantity': qty,
        'unit_price': price,
      });
    }
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Enter quantities to return')));
      return;
    }
    try {
      // Ensure purchase link
      if (_linkedPurchaseId == null) {
        await _linkPurchaseForSupplier();
      }
      final purchaseId = _linkedPurchaseId;
      final purchase = _linkedPurchase;
      if (purchaseId == null || purchase == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
              content: Text(
                  'No existing purchase found for supplier to link return')));
        return;
      }
      // map purchase_detail_id if available
      final details =
          (purchase['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      for (final p in payload) {
        final pid = p['product_id'] as int;
        final match = details.firstWhere(
          (d) => (d['product_id'] as int) == pid,
          orElse: () => const {},
        );
        final pdid = match['purchase_detail_id'] as int?;
        if (pdid != null) p['purchase_detail_id'] = pdid;
      }

      final id = await ref.read(purchaseReturnsRepositoryProvider).createReturn(
            purchaseId: purchaseId,
            items: payload,
            reason: _reason.text.trim().isEmpty ? null : _reason.text.trim(),
          );
      final file = (_receiptFilePath ?? '').trim();
      final number = _receiptNumber.text.trim();
      if (file.isNotEmpty) {
        try {
          await ref.read(purchaseReturnsRepositoryProvider).uploadReceipt(
              returnId: id,
              filePath: file,
              receiptNumber: number.isEmpty ? null : number);
        } catch (_) {}
      }
      if (!mounted) return;
      Navigator.of(context).pop(id);
    } catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Return')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SupplierPicker(
              supplierId: _supplierId,
              supplierName: _supplierName,
              onPicked: (id, name) async {
                setState(() {
                  _supplierId = id;
                  _supplierName = name;
                });
                await _linkPurchaseForSupplier();
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _receiptNumber,
              decoration: const InputDecoration(
                labelText: 'Return Receipt Number (optional)',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Return Receipt (optional)',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _receiptFilePath == null
                        ? 'No file selected'
                        : (_receiptFilePath!.split('\\').last.split('/').last),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickReceiptFile,
                icon: const Icon(Icons.attach_file_rounded),
                label: const Text('Choose File'),
              ),
            ]),
            const SizedBox(height: 12),
            if (_loadingLink) const LinearProgressIndicator(minHeight: 2),
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildLines(context),
            const SizedBox(height: 8),
            Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                    onPressed: () => setState(() => _lines.add(_RetLine())),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add Item'))),
            const SizedBox(height: 16),
            SizedBox(
                height: 48,
                child: FilledButton(
                    onPressed: _save, child: const Text('Save Return'))),
          ],
        ),
      ),
    );
  }
}

class _RetLine {
  InventoryListItem? product;
  final qty = TextEditingController();
  final price = TextEditingController();
  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

extension on _ReturnFormPageState {
  List<Widget> _buildLines(BuildContext context) {
    Theme.of(context);
    final details = ((_linkedPurchase?['items'] as List?) ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    final Map<int, double> defaultPrices = {
      for (final it in details)
        if (it['product_id'] != null)
          (it['product_id'] as int): ((it['unit_price'] as num?)?.toDouble() ??
              (it['price'] as num?)?.toDouble() ??
              0.0),
    };
    return [
      for (int i = 0; i < _lines.length; i++)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              _LineProductPicker(line: _lines[i], defaultPrices: defaultPrices),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: TextField(
                        controller: _lines[i].qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Quantity',
                            prefixIcon:
                                Icon(Icons.format_list_numbered_rounded)))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _lines[i].price,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                            labelText: 'Unit Price',
                            prefixIcon: Icon(Icons.currency_rupee_rounded)))),
                IconButton(
                    onPressed: _lines.length == 1
                        ? null
                        : () => setState(() => _lines.removeAt(i)),
                    icon: const Icon(Icons.delete_outline_rounded))
              ]),
            ]),
          ),
        ),
    ];
  }
}

class _LineProductPicker extends ConsumerStatefulWidget {
  const _LineProductPicker({required this.line, required this.defaultPrices});
  final _RetLine line;
  final Map<int, double> defaultPrices;
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
        if (picked != null) {
          setState(() => widget.line.product = picked);
          // Auto-fill unit price from latest purchase for this supplier if available
          final current = widget.line.price.text.trim();
          if (current.isEmpty) {
            final dp = widget.defaultPrices[picked.productId];
            if (dp != null) {
              widget.line.price.text = dp.toStringAsFixed(2);
            } else if (picked.price != null) {
              widget.line.price.text = picked.price!.toStringAsFixed(2);
            }
          }
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
            labelText: 'Product',
            prefixIcon: Icon(Icons.inventory_2_rounded),
            border: OutlineInputBorder()),
        child: Row(children: [
          Expanded(
              child: Text(
                  p == null
                      ? 'Tap to select a product'
                      : '${p.name}${(p.sku ?? '').isNotEmpty ? ' · SKU: ${p.sku}' : ''}',
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
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
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
                        }),
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
                                      onChanged: (v) =>
                                          setInner(() => selectedId = v),
                                      title: Text(it.name),
                                      subtitle: Text([
                                        (it.sku ?? '').isNotEmpty
                                            ? 'SKU: ${it.sku}'
                                            : null,
                                        'Stock: ${it.stock.toStringAsFixed(2)}'
                                      ].whereType<String>().join(' · ')));
                                }))
                  ]),
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
                                price: null));
                        Navigator.pop(context, it.productId == -1 ? null : it);
                      },
                      child: const Text('Select'))
                ],
              )),
    );
  }
}

// Local supplier picker widget, adapted from GRN/PO forms
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
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(child: Text(display, overflow: TextOverflow.ellipsis)),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
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
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) async {
                    final q = v.trim();
                    try {
                      final list =
                          await repo.getSuppliers(search: q.isEmpty ? null : q);
                      setInner(() => results = list);
                    } catch (_) {}
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
                final s = results.firstWhere(
                  (e) => e.supplierId == selected,
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
                          lastPurchaseDate: null,
                        )
                      : results.first,
                );
                if (s.supplierId <= 0) {
                  Navigator.pop(context, null);
                  return;
                }
                Navigator.pop(context, (s.supplierId, s.name));
              },
              child: const Text('Select'),
            )
          ],
        ),
      ),
    );
  }
}
