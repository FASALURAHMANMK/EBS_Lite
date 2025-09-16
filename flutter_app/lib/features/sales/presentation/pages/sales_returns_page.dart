import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../pos/presentation/widgets/customer_selector_dialog.dart';
import '../../data/sales_repository.dart';
import 'sale_return_detail_page.dart';

class SaleReturnFormPage extends ConsumerStatefulWidget {
  const SaleReturnFormPage({super.key});
  @override
  ConsumerState<SaleReturnFormPage> createState() => _SaleReturnFormPageState();
}

class _SaleReturnFormPageState extends ConsumerState<SaleReturnFormPage> {
  PosCustomerDto? _customer;
  SaleDto? _linkedSale;
  bool _linking = false;
  final _invoiceCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final List<_RetLine> _lines = [
    _RetLine(),
  ];

  @override
  void dispose() {
    _invoiceCtrl.dispose();
    _reasonCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }


  Future<void> _findInvoice() async {
    final code = _invoiceCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _linking = true);
    try {
      final list = await ref.read(salesRepositoryProvider).getSalesHistory(saleNumber: code);
      if (list.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('No invoice found')));
        return;
      }
      final id = list.first['sale_id'] as int?;
      if (id == null) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('Invalid invoice selected')));
        return;
      }
      final sale = await ref.read(posRepositoryProvider).getSaleById(id);
      if (!mounted) return;
      setState(() => _linkedSale = sale);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  Future<void> _save() async {
    // Build lines
    final items = <Map<String, dynamic>>[];
    for (final l in _lines) {
      if (l.product == null) continue;
      final qty = double.tryParse(l.qty.text.trim()) ?? 0;
      if (qty <= 0) continue;
      final price = double.tryParse(l.price.text.trim()) ?? 0;
      if (price <= 0) continue;
      items.add({
        'product_id': l.product!.productId,
        'quantity': qty,
        'unit_price': price,
      });
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Enter items to return')));
      return;
    }

    final customer = _customer;
    final sale = _linkedSale;
    try {
      int returnId;
      if (customer == null) {
        // Walk-in: invoice mandatory
        if (sale == null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(const SnackBar(content: Text('Invoice number required for walk-in returns')));
          return;
        }
        returnId = await ref.read(salesRepositoryProvider).createSaleReturn(
              saleId: sale.saleId,
              items: items,
              reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
            );
      } else {
        if (sale != null) {
          // Customer selected with invoice
          returnId = await ref.read(salesRepositoryProvider).createSaleReturn(
                saleId: sale.saleId,
                items: items,
                reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
              );
        } else {
          // Customer selected, invoice optional – let backend locate a sale
          returnId = await ref.read(salesRepositoryProvider).createSaleReturnByCustomer(
                customerId: customer.customerId,
                items: items,
                reason: _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
              );
        }
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SaleReturnDetailPage(returnId: returnId)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sale = _linkedSale;
    return Scaffold(
      appBar: AppBar(title: const Text('New Sale Return')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CustomerPicker(customer: _customer, onPicked: (c) => setState(() => _customer = c)),
            const SizedBox(height: 12),
            TextField(
              controller: _invoiceCtrl,
              decoration: InputDecoration(
                labelText: 'Invoice Number ${_customer == null ? '(required for walk-in)' : '(optional)'}',
                prefixIcon: const Icon(Icons.receipt_long_outlined),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search_rounded),
                  onPressed: _findInvoice,
                ),
              ),
              onSubmitted: (_) => _findInvoice(),
            ),
            if (_linking) const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
            if (sale != null)
              Card(
                elevation: 0,
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_rounded),
                  title: Text(sale.saleNumber),
                  subtitle: Text([
                    if ((sale.customerName ?? '').isNotEmpty) sale.customerName!,
                  ].where((e) => e.isNotEmpty).join(' · ')),
                  trailing: Text(sale.totalAmount.toStringAsFixed(2), style: Theme.of(context).textTheme.titleMedium),
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Text('Items', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildLines(context),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _lines.add(_RetLine())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Item'),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(height: 48, child: FilledButton(onPressed: _save, child: const Text('Save Return'))),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLines(BuildContext context) {
    Theme.of(context);
    // Defaults from linked sale if present
    final saleItems = (_linkedSale?.items ?? const <SaleItemDto>[]);
    final defaultPrices = <int, double>{
      for (final it in saleItems)
        if (it.productId != null) it.productId!: it.unitPrice,
    };
    return [
      for (int i = 0; i < _lines.length; i++)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _LineProductPicker(line: _lines[i], defaultPrices: defaultPrices),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lines[i].qty,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          prefixIcon: Icon(Icons.format_list_numbered_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _lines[i].price,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit Price',
                          prefixIcon: Icon(Icons.currency_rupee_rounded),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _lines.length == 1
                          ? null
                          : () => setState(() => _lines.removeAt(i)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
    ];
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

class _LineProductPicker extends ConsumerStatefulWidget {
  const _LineProductPicker({required this.line, required this.defaultPrices});
  final _RetLine line;
  final Map<int, double> defaultPrices;
  @override
  ConsumerState<_LineProductPicker> createState() => _LineProductPickerState();
}

class _LineProductPickerState extends ConsumerState<_LineProductPicker> {
  final _controller = TextEditingController();
  List<InventoryListItem> _suggestions = const [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    setState(() => _loading = true);
    try {
      final list = await ref.read(inventoryRepositoryProvider).searchProducts(q);
      if (!mounted) return;
      setState(() => _suggestions = list.take(8).toList());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Product',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () => setState(() => _suggestions = const []),
                  ),
          ),
          onChanged: (v) => _search(v.trim()),
        ),
        const SizedBox(height: 6),
        if (_suggestions.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _suggestions
                  .map((p) => ListTile(
                        dense: true,
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: Text(p.name),
                        subtitle: Text('Stock: ${p.stock.toStringAsFixed(2)}  ·  Price: ${(p.price ?? 0).toStringAsFixed(2)}'),
                        onTap: () {
                          setState(() {
                            widget.line.product = p;
                            _controller.text = p.name;
                            final defaultPrice = widget.defaultPrices[p.productId] ?? p.price ?? 0.0;
                            widget.line.price.text = defaultPrice.toStringAsFixed(2);
                            _suggestions = const [];
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({required this.customer, required this.onPicked});
  final PosCustomerDto? customer;
  final void Function(PosCustomerDto? c) onPicked;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDialog<PosCustomerDto>(
          context: context,
          builder: (_) => const CustomerSelectorDialog(),
        );
        if (picked != null) onPicked(picked);
      },
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Customer (optional)',
          prefixIcon: Icon(Icons.person_search_rounded),
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                customer == null ? 'Walk in' : customer!.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded),
          ],
        ),
      ),
    );
  }
}
