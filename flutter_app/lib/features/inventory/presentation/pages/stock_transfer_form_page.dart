import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/models.dart';
import '../../data/inventory_repository.dart';
import '../../data/models.dart';
import '../../../../core/error_handler.dart';

enum TransferMode { transfer, request }

class StockTransferFormPage extends ConsumerStatefulWidget {
  const StockTransferFormPage({super.key, this.mode = TransferMode.transfer});
  final TransferMode mode;

  @override
  ConsumerState<StockTransferFormPage> createState() => _StockTransferFormPageState();
}

class _LineItem { int? productId; String? name; double qty = 0; }

class _StockTransferFormPageState extends ConsumerState<StockTransferFormPage> {
  final _formKey = GlobalKey<FormState>();
  int? _fromLocationId; // used only in request mode (override)
  int? _toLocationId;   // used only in transfer mode (pick dest)
  final List<_LineItem> _items = [ _LineItem() ];
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final sel = ref.read(locationNotifierProvider).selected;
    if (widget.mode == TransferMode.transfer) {
      // Source = selected; choose destination
      _toLocationId = null;
    } else {
      // Request: Destination = selected; choose source
      _fromLocationId = null;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final repo = ref.read(inventoryRepositoryProvider);
    setState(() => _saving = true);
    try {
      // Build items payload
      final payload = _items.where((e) => (e.productId ?? 0) > 0 && e.qty > 0).map((e) => {
        'product_id': e.productId,
        'quantity': e.qty,
      }).toList();
      if (payload.isEmpty) throw Exception('At least one line item required');

      final selectedLoc = ref.read(locationNotifierProvider).selected;
      final selectedId = selectedLoc?.locationId;
      if (selectedId == null) throw Exception('No selected location');

      int? fromOverride;
      int toId;
      if (widget.mode == TransferMode.transfer) {
        toId = _toLocationId ?? -1;
        if (toId <= 0) throw Exception('Select destination location');
        if (toId == selectedId) {
          throw Exception('Source and destination cannot be the same location');
        }
        // source = selected location by default, no override
      } else {
        // request: to = selected, from = chosen
        toId = selectedId;
        fromOverride = _fromLocationId;
        if (fromOverride == null || fromOverride <= 0) throw Exception('Select source location');
        if (fromOverride == selectedId) {
          throw Exception('Source and destination cannot be the same location');
        }
      }

      // Validate quantities against available stock at source
      for (final e in _items) {
        final pid = e.productId;
        final qty = e.qty;
        if (pid == null || qty <= 0) continue;
        final checkSource = (widget.mode == TransferMode.request)
            ? fromOverride
            : selectedId;
        if (checkSource == null || checkSource <= 0) {
          throw Exception('Source location is not selected');
        }
        final stockItem = await repo.getStockForProductAtLocation(productId: pid, locationId: checkSource);
        final avail = stockItem?.stock ?? 0;
        if (qty > avail + 1e-9) { // tolerance
          throw Exception("Requested quantity for '${e.name ?? 'Product #$pid'}' (${qty.toStringAsFixed(3)}) exceeds available (${avail.toStringAsFixed(3)}) at source.");
        }
      }

      await repo.createStockTransfer(
        toLocationId: toId,
        items: payload,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        fromLocationIdOverride: fromOverride,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed to submit: ${ErrorHandler.message(e)}')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locState = ref.watch(locationNotifierProvider);
    final locations = locState.locations;
    final theme = Theme.of(context);
    final isRequest = widget.mode == TransferMode.request;
    return Scaffold(
      appBar: AppBar(title: Text(isRequest ? 'Request Stock' : 'New Transfer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (isRequest)
              _LocationDropdown(
                label: 'From Location',
                value: _fromLocationId,
                locations: locations,
                onChanged: (v) => setState(() => _fromLocationId = v),
              )
            else
              _LocationDropdown(
                label: 'To Location',
                value: _toLocationId,
                locations: locations,
                onChanged: (v) => setState(() => _toLocationId = v),
              ),
            const SizedBox(height: 12),
            Text('Items', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var i = 0; i < _items.length; i++)
              _LineEditor(
                key: ValueKey('line_$i'),
                line: _items[i],
                sourceLocationId: widget.mode == TransferMode.request
                    ? _fromLocationId
                    : ref.watch(locationNotifierProvider).selected?.locationId,
                onRemove: _items.length > 1 ? () => setState(() => _items.removeAt(i)) : null,
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded),
                onPressed: () => setState(() => _items.add(_LineItem())),
                label: const Text('Add item'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send_rounded),
                label: Text(isRequest ? 'Send Request' : 'Create Transfer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({required this.label, required this.value, required this.locations, required this.onChanged});
  final String label;
  final int? value;
  final List<Location> locations;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          isExpanded: true,
          value: value,
          items: locations.map((l) => DropdownMenuItem<int?>(value: l.locationId, child: Text(l.name))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _LineEditor extends ConsumerStatefulWidget {
  const _LineEditor({super.key, required this.line, this.onRemove, required this.sourceLocationId});
  final _LineItem line;
  final VoidCallback? onRemove;
  final int? sourceLocationId;
  @override
  ConsumerState<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends ConsumerState<_LineEditor> {
  final _qtyCtrl = TextEditingController();
  double? _available;
  int? _lastProductId;
  int? _lastSourceLoc;

  @override
  void initState() {
    super.initState();
    _qtyCtrl.text = widget.line.qty > 0 ? widget.line.qty.toString() : '';
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadAvailable());
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _LineEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeLoadAvailable();
  }

  Future<void> _maybeLoadAvailable() async {
    final pid = widget.line.productId;
    final src = widget.sourceLocationId;
    if (pid == null || src == null || src <= 0) {
      setState(() => _available = null);
      _lastProductId = pid;
      _lastSourceLoc = src;
      return;
    }
    if (_lastProductId == pid && _lastSourceLoc == src) return;
    _lastProductId = pid;
    _lastSourceLoc = src;
    try {
      final repo = ref.read(inventoryRepositoryProvider);
      final item = await repo.getStockForProductAtLocation(productId: pid, locationId: src);
      if (!mounted) return;
      setState(() => _available = item?.stock);
    } catch (_) {
      if (!mounted) return;
      setState(() => _available = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(children: [
              Expanded(child: _ProductPicker(line: widget.line, onPicked: () async { await _maybeLoadAvailable(); })),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: TextFormField(
                  controller: _qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) {
                    final q = double.tryParse((v ?? '').trim());
                    if (q == null || q <= 0) return 'Required';
                    if (_available != null && q > (_available! + 1e-9)) {
                      return 'Exceeds available (${_available!.toStringAsFixed(3)})';
                    }
                    return null;
                  },
                  onChanged: (v) => widget.line.qty = double.tryParse(v.trim()) ?? 0,
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onRemove != null)
                IconButton(onPressed: widget.onRemove, icon: const Icon(Icons.remove_circle_outline_rounded)),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _available == null
                    ? (widget.sourceLocationId == null ? 'Select source location to view availability' : 'Available: —')
                    : 'Available: ${_available!.toStringAsFixed(3)}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPicker extends ConsumerWidget {
  const _ProductPicker({required this.line, this.onPicked});
  final _LineItem line;
  final Future<void> Function()? onPicked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () async {
        final product = await _openDialog(context, ref);
        if (product != null) {
          line.productId = product.productId;
          line.name = product.name;
          (context as Element).markNeedsBuild();
          if (onPicked != null) await onPicked!();
        }
      },
      child: InputDecorator(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.inventory_2_rounded), hintText: 'Select product', border: OutlineInputBorder()),
        child: Text(line.name ?? 'Select product', style: theme.textTheme.bodyMedium),
      ),
    );
  }

  Future<InventoryListItem?> _openDialog(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(inventoryRepositoryProvider);
    String query = '';
    List<InventoryListItem> results = const [];
    return showDialog<InventoryListItem>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AlertDialog(
          title: const Text('Select Product'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(hintText: 'Search', prefixIcon: Icon(Icons.search_rounded)),
                  onChanged: (v) async {
                    query = v.trim();
                    if (query.length < 2) {
                      setInner(() => results = const []);
                      return;
                    }
                    final list = await repo.searchProducts(query);
                    setInner(() => results = list);
                  },
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final p = results[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text([(p.sku ?? ''), if ((p.categoryName ?? '').isNotEmpty) p.categoryName!].where((e) => e != null && e.toString().isNotEmpty).join(' · ')),
                        onTap: () => Navigator.of(context).pop(p),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ],
        ),
      ),
    );
  }
}
