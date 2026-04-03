import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../dashboard/data/payment_methods_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';
import 'sale_detail_page.dart';

class B2BInvoiceFormPage extends ConsumerStatefulWidget {
  const B2BInvoiceFormPage({super.key});

  @override
  ConsumerState<B2BInvoiceFormPage> createState() => _B2BInvoiceFormPageState();
}

class _B2BInvoiceFormPageState extends ConsumerState<B2BInvoiceFormPage> {
  final _discount = TextEditingController(text: '0');
  final _paid = TextEditingController(text: '0');
  final _notes = TextEditingController();

  PosCustomerDto? _customer;
  PaymentMethodDto? _paymentMethod;
  final List<_InvoiceLine> _lines = [_InvoiceLine()];
  bool _saving = false;

  @override
  void dispose() {
    _discount.dispose();
    _paid.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
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
            Future<void> doSearch(String query) async {
              loading = true;
              setStateDialog(() {});
              try {
                results = await repo.searchCustomers(
                  query,
                  customerType: 'B2B',
                );
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => doSearch(''));
            }

            return AppSelectionDialog(
              title: 'Select B2B Party',
              maxWidth: 480,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: 'Search parties',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search_rounded),
                    onPressed: () => doSearch(controller.text.trim()),
                  ),
                ),
                onChanged: (value) => doSearch(value.trim()),
                onSubmitted: (value) => doSearch(value.trim()),
              ),
              body: results.isEmpty && !loading
                  ? const Center(child: Text('No B2B parties found'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, index) {
                        final item = results[index];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text(
                            [
                              if ((item.contactPerson ?? '').isNotEmpty)
                                item.contactPerson!,
                              if ((item.phone ?? '').isNotEmpty) item.phone!,
                              if ((item.email ?? '').isNotEmpty) item.email!,
                            ].join(' • '),
                          ),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
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

  Future<void> _pickPaymentMethod() async {
    final methods = await ref.read(posRepositoryProvider).getPaymentMethods();
    if (!mounted) return;
    final result = await showDialog<PaymentMethodDto>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Payment Method'),
        children: [
          for (final method in methods)
            SimpleDialogOption(
              onPressed: () => Navigator.of(dialogContext).pop(method),
              child: Text(method.name),
            ),
        ],
      ),
    );
    if (result != null) {
      setState(() => _paymentMethod = result);
    }
  }

  Future<void> _configureTracking(_InvoiceLine line) async {
    final product = line.product;
    if (product == null) return;
    final qty = double.tryParse(line.quantity.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter quantity first')),
        );
      return;
    }
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: product.productId,
      productName: product.name,
      quantity: qty,
      mode: InventoryTrackingMode.issue,
      initialSelection: line.tracking,
    );
    if (selection != null && mounted) {
      setState(() => line.tracking = selection);
    }
  }

  Future<void> _save() async {
    final customer = _customer;
    if (customer == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select a B2B party')),
        );
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final line in _lines) {
      final product = line.product;
      if (product == null) continue;
      final quantity = double.tryParse(line.quantity.text.trim()) ?? 0;
      final unitPrice = double.tryParse(line.unitPrice.text.trim()) ?? 0;
      if (quantity <= 0 || unitPrice <= 0) continue;
      final requiresTracking =
          product.trackingType == 'BATCH' || product.trackingType == 'SERIAL';
      if (requiresTracking && line.tracking == null) {
        throw StateError(
          'Configure inventory tracking for ${product.name}',
        );
      }
      items.add({
        'product_id': product.productId,
        if (product.barcodeId != null) 'barcode_id': product.barcodeId,
        'quantity': quantity,
        'unit_price': unitPrice,
        if (line.tracking != null) ...line.tracking!.toIssueJson(),
      });
    }

    if (items.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Add at least one invoice item')),
        );
      return;
    }

    final paidAmount = double.tryParse(_paid.text.trim()) ?? 0;
    if (paidAmount > 0 && _paymentMethod == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Select a payment method for paid amount'),
          ),
        );
      return;
    }

    setState(() => _saving = true);
    try {
      final saleId = await ref.read(salesRepositoryProvider).createInvoice(
            customerId: customer.customerId,
            items: items,
            paymentMethodId: _paymentMethod?.methodId,
            paidAmount: paidAmount,
            discountAmount: double.tryParse(_discount.text.trim()) ?? 0,
            notes: _notes.text.trim(),
            transactionType: 'B2B',
          );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New B2B Invoice')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_rounded),
              title: Text(_customer?.name ?? 'Select B2B Party'),
              subtitle: Text(
                [
                  if ((_customer?.contactPerson ?? '').isNotEmpty)
                    _customer!.contactPerson!,
                  if ((_customer?.phone ?? '').isNotEmpty) _customer!.phone!,
                ].join(' • '),
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickCustomer,
            ),
            const SizedBox(height: 12),
            ..._lines.asMap().entries.map((entry) {
              final index = entry.key;
              final line = entry.value;
              final requiresTracking = line.product != null &&
                  (line.product!.trackingType == 'BATCH' ||
                      line.product!.trackingType == 'SERIAL');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _InvoiceProductPicker(line: line),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: line.quantity,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Quantity',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: line.unitPrice,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: const InputDecoration(
                                  labelText: 'Unit Price',
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _lines.length == 1
                                  ? null
                                  : () => setState(() {
                                        line.dispose();
                                        _lines.removeAt(index);
                                      }),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                        if (requiresTracking) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => _configureTracking(line),
                              icon: const Icon(Icons.qr_code_2_rounded),
                              label: Text(
                                line.tracking == null
                                    ? 'Configure Tracking'
                                    : line.tracking!.summary(
                                        double.tryParse(
                                              line.quantity.text.trim(),
                                            ) ??
                                            0,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _lines.add(_InvoiceLine())),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Item'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _discount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration:
                        const InputDecoration(labelText: 'Header Discount'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _paid,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Paid Amount'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.payments_outlined),
              title: Text(_paymentMethod?.name ?? 'Select Payment Method'),
              subtitle: const Text('Optional unless paid amount is entered'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickPaymentMethod,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving...' : 'Create B2B Invoice'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceLine {
  InventoryListItem? product;
  InventoryTrackingSelection? tracking;
  final quantity = TextEditingController();
  final unitPrice = TextEditingController();

  void dispose() {
    quantity.dispose();
    unitPrice.dispose();
  }
}

class _InvoiceProductPicker extends ConsumerStatefulWidget {
  const _InvoiceProductPicker({required this.line});

  final _InvoiceLine line;

  @override
  ConsumerState<_InvoiceProductPicker> createState() =>
      _InvoiceProductPickerState();
}

class _InvoiceProductPickerState extends ConsumerState<_InvoiceProductPicker> {
  final _controller = TextEditingController();
  List<InventoryListItem> _suggestions = const [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String value) async {
    setState(() => _loading = true);
    try {
      final items = await ref.read(inventoryRepositoryProvider).searchProducts(
            value,
          );
      if (!mounted) return;
      setState(() => _suggestions = items.take(8).toList());
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
                    padding: EdgeInsets.all(10),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
          onChanged: (value) => _search(value.trim()),
        ),
        if (widget.line.product != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.line.product!.name,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
        if (_suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: _suggestions
                  .map(
                    (item) => ListTile(
                      dense: true,
                      title: Text(item.name),
                      subtitle: Text(
                        [
                          'Stock ${item.stock.toStringAsFixed(2)}',
                          'Price ${(item.price ?? 0).toStringAsFixed(2)}',
                        ].join(' • '),
                      ),
                      onTap: () {
                        setState(() {
                          widget.line.product = item;
                          widget.line.unitPrice.text =
                              (item.price ?? 0).toStringAsFixed(2);
                          _controller.text = item.name;
                          _suggestions = const [];
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ],
    );
  }
}
