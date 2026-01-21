import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';

class QuoteFormPage extends ConsumerStatefulWidget {
  const QuoteFormPage({super.key, this.quoteId});
  final int? quoteId;

  @override
  ConsumerState<QuoteFormPage> createState() => _QuoteFormPageState();
}

class _QuoteFormPageState extends ConsumerState<QuoteFormPage> {
  final _discountCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  PosCustomerDto? _customer;
  DateTime? _validUntil;
  List<PosCartItem> _items = const [];
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.quoteId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadQuote();
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(salesRepositoryProvider);
      final quote = await repo.getQuote(widget.quoteId!);
      final discount =
          (quote['discount_amount'] as num?)?.toDouble() ?? 0.0;
      _discountCtrl.text = discount.toStringAsFixed(2);
      _notesCtrl.text = quote['notes']?.toString() ?? '';
      final customer = quote['customer'] as Map<String, dynamic>?;
      if (customer != null) {
        _customer = PosCustomerDto(
          customerId: customer['customer_id'] as int? ?? 0,
          name: customer['name']?.toString() ?? '',
          phone: customer['phone']?.toString(),
          email: customer['email']?.toString(),
        );
      }
      final validUntilStr = quote['valid_until']?.toString();
      if (validUntilStr != null && validUntilStr.isNotEmpty) {
        _validUntil = DateTime.tryParse(validUntilStr);
      }
      final items = (quote['items'] as List<dynamic>? ?? [])
          .map((raw) {
            final i = raw as Map<String, dynamic>;
            final productId = i['product_id'] as int? ?? 0;
            final name = (i['product_name'] ??
                    i['product']?['name'] ??
                    'Item')
                .toString();
            return PosCartItem(
              product: PosProductDto(
                productId: productId,
                name: name,
                price: (i['unit_price'] as num?)?.toDouble() ?? 0.0,
                stock: 0,
              ),
              quantity: (i['quantity'] as num?)?.toDouble() ?? 0.0,
              unitPrice: (i['unit_price'] as num?)?.toDouble() ?? 0.0,
              discountPercent:
                  (i['discount_percentage'] as num?)?.toDouble() ?? 0.0,
            );
          })
          .toList();
      _items = items;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _lineTotal(PosCartItem item) {
    final raw = item.quantity * item.unitPrice;
    final discount = raw * (item.discountPercent / 100);
    return raw - discount;
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _validUntil = picked);
    }
  }

  Future<void> _pickCustomer() async {
    final result = await showDialog<PosCustomerDto>(
      context: context,
      builder: (context) {
        final repo = ref.read(posRepositoryProvider);
        final controller = TextEditingController();
        List<PosCustomerDto> results = const [];
        bool loading = true;
        bool kickoff = true;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> doSearch(String q) async {
              loading = true;
              setStateDialog(() {});
              try {
                results = await repo.searchCustomers(q);
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => doSearch(''));
            }

            return AlertDialog(
              title: const Text('Select Customer'),
              content: SizedBox(
                width: 420,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Search customers',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () =>
                              doSearch(controller.text.trim()),
                        ),
                      ),
                      onSubmitted: (v) => doSearch(v.trim()),
                    ),
                    const SizedBox(height: 8),
                    if (loading)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: results.isEmpty && !loading
                          ? const Center(child: Text('No customers'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final c = results[i];
                                return ListTile(
                                  title: Text(c.name),
                                  subtitle: Text([
                                    if ((c.phone ?? '').isNotEmpty) c.phone!,
                                    if ((c.email ?? '').isNotEmpty) c.email!,
                                  ].where((e) => e.isNotEmpty).join(' - ')),
                                  onTap: () =>
                                      Navigator.of(context).pop(c),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() => _customer = result);
    }
  }

  Future<void> _pickProduct() async {
    final picked = await showDialog<PosProductDto>(
      context: context,
      builder: (context) {
        final repo = ref.read(posRepositoryProvider);
        final controller = TextEditingController();
        List<PosProductDto> results = const [];
        bool loading = true;
        bool kickoff = true;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> doSearch(String q) async {
              loading = true;
              setStateDialog(() {});
              try {
                results = await repo.searchProducts(q);
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => doSearch(''));
            }

            return AlertDialog(
              title: const Text('Add Item'),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Search products',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search_rounded),
                          onPressed: () =>
                              doSearch(controller.text.trim()),
                        ),
                      ),
                      onSubmitted: (v) => doSearch(v.trim()),
                    ),
                    const SizedBox(height: 8),
                    if (loading)
                      const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: results.isEmpty && !loading
                          ? const Center(child: Text('No products'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (context, i) {
                                final p = results[i];
                                return ListTile(
                                  title: Text(p.name),
                                  subtitle: Text(
                                      'Price: ${p.price.toStringAsFixed(2)}'),
                                  onTap: () =>
                                      Navigator.of(context).pop(p),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );

    if (picked != null) {
      final items = [..._items];
      final idx =
          items.indexWhere((i) => i.product.productId == picked.productId);
      if (idx >= 0) {
        items[idx] =
            items[idx].copyWith(quantity: items[idx].quantity + 1);
      } else {
        items.add(PosCartItem(
          product: picked,
          quantity: 1,
          unitPrice: picked.price,
        ));
      }
      setState(() => _items = items);
    }
  }

  Future<void> _editItem(PosCartItem item) async {
    final qtyCtrl =
        TextEditingController(text: item.quantity.toString());
    final priceCtrl =
        TextEditingController(text: item.unitPrice.toString());
    final discCtrl =
        TextEditingController(text: item.discountPercent.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item.product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity'),
            ),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Unit Price'),
            ),
            TextField(
              controller: discCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Discount %'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final qty = double.tryParse(qtyCtrl.text.trim()) ?? item.quantity;
      final price =
          double.tryParse(priceCtrl.text.trim()) ?? item.unitPrice;
      final disc =
          double.tryParse(discCtrl.text.trim()) ?? item.discountPercent;
      final updated = item.copyWith(
        quantity: qty,
        unitPrice: price,
        discountPercent: disc,
      );
      final items = _items.map((i) => i == item ? updated : i).toList();
      setState(() => _items = items);
    }
  }

  Future<void> _submit() async {
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    if (_items.isEmpty) {
      setState(() => _error = 'Add at least one item');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(salesRepositoryProvider);
      final payloadItems = _items
          .map((i) => {
                'product_id': i.product.productId,
                'quantity': i.quantity,
                'unit_price': i.unitPrice,
                'discount_percentage': i.discountPercent,
              })
          .toList();
      if (_isEdit) {
        await repo.updateQuote(
          widget.quoteId!,
          status: null,
          notes: _notesCtrl.text.trim(),
          validUntil: _validUntil,
          discountAmount: discount,
          items: payloadItems,
        );
      } else {
        await repo.createQuote(
          customerId: _customer?.customerId,
          validUntil: _validUntil,
          discountAmount: discount,
          notes: _notesCtrl.text.trim(),
          items: payloadItems,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtotal = _items.fold<double>(0, (sum, i) => sum + _lineTotal(i));
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    final total = (subtotal - discount).clamp(0.0, double.infinity);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Quote' : 'New Quote'),
        actions: [
          IconButton(
            tooltip: 'Add Item',
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _pickProduct,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person_rounded),
                    title: Text(_customer?.name ?? 'Walk in'),
                    subtitle: Text(_customer == null ? 'No customer selected' : 'Customer'),
                    trailing: TextButton(
                      onPressed: _pickCustomer,
                      child: const Text('Select'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.event_rounded),
                    title: Text(_validUntil == null
                        ? 'Valid until: not set'
                        : 'Valid until: ${_validUntil!.toIso8601String().split('T').first}'),
                    trailing: TextButton(
                      onPressed: _pickValidUntil,
                      child: const Text('Pick'),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Discount amount',
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: TextField(
                      controller: _notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Items'),
                    trailing: TextButton(
                      onPressed: _pickProduct,
                      child: const Text('Add'),
                    ),
                  ),
                  const Divider(height: 1),
                  if (_items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('No items added'),
                    )
                  else
                    for (final item in _items)
                      ListTile(
                        leading: const Icon(Icons.inventory_2_rounded),
                        title: Text(item.product.name),
                        subtitle: Text(
                          'Qty: ${item.quantity} - Price: ${item.unitPrice.toStringAsFixed(2)} - Disc: ${item.discountPercent.toStringAsFixed(1)}%',
                        ),
                        trailing: Text(
                          _lineTotal(item).toStringAsFixed(2),
                          style: theme.textTheme.bodyLarge,
                        ),
                        onTap: () => _editItem(item),
                        onLongPress: () {
                          setState(() {
                            _items = [..._items]..remove(item);
                          });
                        },
                      ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              child: ListTile(
                title: const Text('Total'),
                subtitle: Text('Subtotal: ${subtotal.toStringAsFixed(2)}'),
                trailing: Text(total.toStringAsFixed(2),
                    style: theme.textTheme.titleMedium),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_isEdit ? 'Update Quote' : 'Create Quote'),
            ),
          ],
        ),
      ),
    );
  }
}
