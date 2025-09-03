
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../../../dashboard/controllers/location_notifier.dart';

class StockAdjustmentsPage extends ConsumerStatefulWidget {
  const StockAdjustmentsPage({super.key});

  @override
  ConsumerState<StockAdjustmentsPage> createState() => _StockAdjustmentsPageState();
}

class _StockAdjustmentsPageState extends ConsumerState<StockAdjustmentsPage> {
  final _search = TextEditingController();
  List<StockAdjustmentDocumentDto> _all = const [];
  bool _loading = true;

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
      final repo = ref.read(inventoryRepositoryProvider);
      final list = await repo.getStockAdjustmentDocuments();
      if (!mounted) return;
      setState(() => _all = list);
    } catch (e) {
      if (!mounted) return;
      setState(() => _all = const []);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to load documents: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = ref.watch(locationNotifierProvider).selected;
    final locName = loc?.name ?? '—';

    final groups = _all;
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? groups
        : groups.where((g) => g.documentNumber.toLowerCase().contains(q) || (g.reason ?? '').toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Adjustments'),
        actions: [
          IconButton(
            tooltip: 'New Adjustment',
            icon: const Icon(Icons.add_rounded),
            onPressed: () async {
              final docId = await Navigator.of(context).push<String>(
                MaterialPageRoute(builder: (_) => const _AdjustmentDocumentFormPage()),
              );
              if (docId != null) {
                await _load();
                if (!mounted) return;
                final id = int.tryParse(docId);
                if (id != null) {
                  // ignore: use_build_context_synchronously
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _AdjustmentDocumentDetailPage(documentId: id)),
                  );
                }
              }
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Location indicator
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text('Location: $locName', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            // Search bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search adjustments (Doc # or reason)',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _loading
                  ? const SizedBox.shrink()
                  : (filtered.isEmpty
                      ? const Center(child: Text('No adjustment documents'))
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemBuilder: (context, i) {
                            final g = filtered[i];
                            final adj = _sum(g.items.map((e) => e.adjustment));
                            final color = adj >= 0 ? Colors.green : theme.colorScheme.error;
                            return Card(
                              elevation: 0,
                              child: ListTile(
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => _AdjustmentDocumentDetailPage(documentId: g.documentId)),
                                ),
                                title: Text(g.documentNumber),
                                subtitle: Text([
                                  if ((g.reason ?? '').isNotEmpty) g.reason!,
                                  if (g.createdAt != null) _fmt(g.createdAt!),
                                  '${g.items.length} item(s)'
                                ].join(' • ')),
                                trailing: Text(
                                  (adj >= 0 ? '+ ' : '') + adj.toStringAsFixed(2),
                                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                                ),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemCount: filtered.length,
                        )),
            ),
          ],
        ),
      ),
    );
  }

  double _sum(Iterable<double> vals) => vals.fold(0.0, (a, b) => a + b);
}


class _AdjustmentDocumentFormPage extends ConsumerStatefulWidget {
  const _AdjustmentDocumentFormPage({super.key});

  @override
  ConsumerState<_AdjustmentDocumentFormPage> createState() => _AdjustmentDocumentFormPageState();
}

class _AdjustmentDocumentFormPageState extends ConsumerState<_AdjustmentDocumentFormPage> {
  final _docReason = TextEditingController();
  bool _saving = false;
  final List<_AdjLine> _lines = [
    _AdjLine(),
  ];

  @override
  void dispose() {
    _docReason.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Adjustment'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _docReason,
              decoration: const InputDecoration(
                labelText: 'Document Reason/Note',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            ..._buildLines(theme),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _lines.add(_AdjLine())),
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
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.4))
                    : const Text('Create Document'),
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
      widgets.add(
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _LineProductPicker(line: _lines[i]),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lines[i].qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Adjustment (+ add, - remove)',
                          prefixIcon: Icon(Icons.tune_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: _lines.length == 1
                          ? null
                          : () => setState(() => _lines.removeAt(i)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final d in const [-10.0, -5.0, -1.0, 1.0, 5.0, 10.0])
                        ActionChip(
                          label: Text(d > 0 ? '+${d.toInt()}' : d.toInt().toString()),
                          onPressed: () {
                            final cur = double.tryParse(_lines[i].qty.text.trim()) ?? 0;
                            final next = cur + d;
                            _lines[i].qty.text = next == next.roundToDouble()
                                ? next.toInt().toString()
                                : next.toStringAsFixed(2);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _save() async {
    // Validate
    final validLines = _lines.where((l) => l.product != null && (double.tryParse(l.qty.text.trim()) ?? 0) != 0).toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Add at least one product with a non-zero adjustment')));
      return;
    }
    final docReason = _docReason.text.trim();
    if (docReason.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please enter a document reason')));
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final items = [
        for (final l in validLines)
          {
            'product_id': l.product!.productId,
            'adjustment': double.tryParse(l.qty.text.trim()) ?? 0,
          }
      ];
      final doc = await repo.createStockAdjustmentDocument(reason: docReason, items: items);
      if (!mounted) return;
      Navigator.of(context).pop(doc.documentId.toString());
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

class _AdjustmentDocumentDetailPage extends ConsumerStatefulWidget {
  const _AdjustmentDocumentDetailPage({required this.documentId});
  final int documentId;

  @override
  ConsumerState<_AdjustmentDocumentDetailPage> createState() => _AdjustmentDocumentDetailPageState();
}

class _AdjustmentDocumentDetailPageState extends ConsumerState<_AdjustmentDocumentDetailPage> {
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
      setState(() { _products = map; _doc = doc; });
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
            Text(d?.createdAt != null ? _fmt(d!.createdAt!) : '', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (d != null) ...d.items.map((a) {
              final name = _products[a.productId]?.name ?? 'Product #${a.productId}';
              final qty = a.adjustment;
              final color = qty >= 0 ? Colors.green : theme.colorScheme.error;
              return Card(
                elevation: 0,
                child: ListTile(
                  title: Text(name),
                  trailing: Text((qty >= 0 ? '+ ' : '') + qty.toStringAsFixed(2), style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}

class _AdjLine {
  InventoryListItem? product;
  final qty = TextEditingController();

  void dispose() {
    qty.dispose();
  }
}

class _LineProductPicker extends ConsumerStatefulWidget {
  const _LineProductPicker({required this.line});
  final _AdjLine line;

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
        child: Row(
          children: [
            Expanded(
              child: Text(
                p == null ? 'Tap to select a product' : '${p.name}${(p.sku ?? '').isNotEmpty ? ' • SKU: ${p.sku}' : ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }

  Future<InventoryListItem?> _openProductPicker(BuildContext context) async {
    final repo = ref.read(inventoryRepositoryProvider);
    List<InventoryListItem> results = [];
    int? selectedId = widget.line.product?.productId;
    String query = '';
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
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (v) async {
                    query = v.trim();
                    if (query.isEmpty) {
                      setInner(() => results = []);
                      return;
                    }
                    final list = await repo.searchProducts(query);
                    setInner(() => results = list);
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: results.isEmpty
                      ? const Center(child: Text('Type to search'))
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
              onPressed: () => Navigator.of(context).maybePop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final it = results.firstWhere(
                  (e) => e.productId == selectedId,
                  orElse: () => widget.line.product ??
                      InventoryListItem(
                        productId: -1,
                        name: '',
                        sku: null,
                        categoryName: null,
                        brandName: null,
                        unitSymbol: null,
                        reorderLevel: 0,
                        stock: 0,
                        isLowStock: false,
                        price: null,
                      ),
                );
                Navigator.of(context).pop(it.productId == -1 ? null : it);
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
  }
}

// Helpers

String _fmt(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$y-$m-$d $hh:$mm';
}
