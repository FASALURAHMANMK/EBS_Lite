import 'package:ebs_lite/features/inventory/data/models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ebs_lite/core/error_handler.dart';
import '../../../../core/outbox/outbox_notifier.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../../suppliers/data/models.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../data/grn_repository.dart';
import '../../data/models.dart';
import '../widgets/cost_adjustment_editor.dart';
import '../../../pos/data/pos_repository.dart';
import '../../../dashboard/data/payment_methods_repository.dart';

class GrnFormPage extends ConsumerStatefulWidget {
  const GrnFormPage({super.key});

  @override
  ConsumerState<GrnFormPage> createState() => _GrnFormPageState();
}

class _GrnFormPageState extends ConsumerState<GrnFormPage> {
  int? _supplierId;
  String? _supplierName;
  final _invoiceNumber = TextEditingController();
  final _notes = TextEditingController();
  String? _invoiceFilePath;
  final List<EditableCostAdjustmentRow> _headerAdjustments = [];

  bool _paidNow = false;
  final _paidAmount = TextEditingController();
  List<PaymentMethodDto> _paymentMethods = const [];
  int? _paymentMethodId;
  bool _loadingPaymentMethods = false;
  Object? _paymentMethodsError;

  final List<_GrnLine> _lines = [
    _GrnLine(),
  ];
  bool _saving = false;

  @override
  void dispose() {
    _invoiceNumber.dispose();
    _notes.dispose();
    _paidAmount.dispose();
    for (final row in _headerAdjustments) {
      row.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('New Goods Receipt')),
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
              controller: _invoiceNumber,
              decoration: const InputDecoration(
                labelText: 'Invoice Number (physical)',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickInvoiceFile,
                    icon: const Icon(Icons.upload_file_rounded),
                    label: Text(_invoiceFilePath == null
                        ? 'Upload Invoice (Image/PDF)'
                        : 'Invoice Selected'),
                  ),
                ),
                if (_invoiceFilePath != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Clear',
                    onPressed: () => setState(() => _invoiceFilePath = null),
                    icon: const Icon(Icons.clear_rounded),
                  )
                ],
              ],
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
            CostAdjustmentListEditor(
              title: 'Header Add-ons',
              rows: _headerAdjustments,
              onAdd: () => setState(
                () => _headerAdjustments.add(EditableCostAdjustmentRow()),
              ),
              onChanged: () => setState(() {}),
              onRemove: (index) => setState(() {
                _headerAdjustments[index].dispose();
                _headerAdjustments.removeAt(index);
              }),
              emptyLabel:
                  'Add freight, duty, rebate, or other header-level costs.',
            ),
            const SizedBox(height: 12),
            _buildPaymentCard(theme),
            const SizedBox(height: 12),
            Text('Items', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildLines(theme),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _lines.add(_GrnLine())),
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
                    : const Text('Create GRN'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCard(ThemeData theme) {
    final total = _computeTotal();
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Payment', style: theme.textTheme.titleMedium),
                ),
                Switch.adaptive(
                  value: _paidNow,
                  onChanged: _saving
                      ? null
                      : (v) async {
                          setState(() {
                            _paidNow = v;
                            _paymentMethodsError = null;
                          });
                          if (!v) return;
                          if (_paidAmount.text.trim().isEmpty ||
                              (double.tryParse(_paidAmount.text.trim()) ?? 0) <=
                                  0) {
                            _paidAmount.text = total.toStringAsFixed(2);
                          }
                          await _loadPaymentMethodsIfNeeded();
                        },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${total.toStringAsFixed(2)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            if (_paidNow) ...[
              const SizedBox(height: 12),
              InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Payment Method',
                  border: const OutlineInputBorder(),
                  prefixIcon: _loadingPaymentMethods
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.payments_outlined),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _paymentMethodId,
                    items: _paymentMethods
                        .where((m) => m.isActive)
                        .map(
                          (m) => DropdownMenuItem<int>(
                            value: m.methodId,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                    onChanged: _saving || _loadingPaymentMethods
                        ? null
                        : (v) => setState(() => _paymentMethodId = v),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _paidAmount,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Paid Amount',
                  prefixIcon: Icon(Icons.currency_exchange_rounded),
                ),
              ),
              if (_paymentMethodsError != null) ...[
                const SizedBox(height: 8),
                Text(
                  ErrorHandler.message(_paymentMethodsError!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 8),
              Text(
                'Leave this off to record the purchase on credit.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  double _computeTotal() {
    double total = 0;
    for (final l in _lines) {
      final qty = double.tryParse(l.qty.text.trim()) ?? 0;
      final price = double.tryParse(l.price.text.trim()) ?? 0;
      if (l.product == null || qty <= 0 || price < 0) continue;
      total += qty * price;
      for (final adjustment in l.adjustments) {
        final draft = adjustment.toDraft();
        if (draft == null) continue;
        total += draft.direction == 'INCOME' ? -draft.amount : draft.amount;
      }
    }
    for (final adjustment in _headerAdjustments) {
      final draft = adjustment.toDraft();
      if (draft == null) continue;
      total += draft.direction == 'INCOME' ? -draft.amount : draft.amount;
    }
    return total;
  }

  Future<void> _loadPaymentMethodsIfNeeded() async {
    if (_paymentMethods.isNotEmpty || _loadingPaymentMethods) return;
    setState(() {
      _loadingPaymentMethods = true;
      _paymentMethodsError = null;
    });
    try {
      final repo = ref.read(posRepositoryProvider);
      final list = await repo.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _paymentMethods = list;
        _paymentMethodId = list.isNotEmpty ? list.first.methodId : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _paymentMethodsError = e);
    } finally {
      if (mounted) setState(() => _loadingPaymentMethods = false);
    }
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
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
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Unit Cost',
                          prefixIcon: Icon(Icons.currency_rupee_rounded),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: _lines.length == 1
                          ? null
                          : () => setState(() => _lines.removeAt(i)),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _configureTracking(_lines[i]),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(
                      _lines[i].tracking == null
                          ? 'Configure Variation / Tracking'
                          : _lines[i].tracking!.summary(
                                double.tryParse(_lines[i].qty.text.trim()) ?? 0,
                              ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CostAdjustmentListEditor(
                  title: 'Item Add-ons',
                  rows: _lines[i].adjustments,
                  onAdd: () => setState(
                    () =>
                        _lines[i].adjustments.add(EditableCostAdjustmentRow()),
                  ),
                  onChanged: () => setState(() {}),
                  onRemove: (index) => setState(() {
                    _lines[i].adjustments[index].dispose();
                    _lines[i].adjustments.removeAt(index);
                  }),
                  emptyLabel:
                      'Add line-level charges or supplier income adjustments for this item.',
                ),
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Future<void> _pickInvoiceFile() async {
    final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg']);
    if (res != null && res.files.single.path != null) {
      setState(() => _invoiceFilePath = res.files.single.path);
    }
  }

  Future<void> _save() async {
    final supplierId = _supplierId;
    if (supplierId == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Please select supplier')));
      return;
    }
    final validLines = _lines
        .where((l) =>
            l.product != null &&
            (double.tryParse(l.qty.text.trim()) ?? 0) > 0 &&
            (double.tryParse(l.price.text.trim()) ?? 0) >= 0)
        .toList();
    if (validLines.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
            content: Text('Add at least one item with quantity and cost')));
      return;
    }
    setState(() => _saving = true);
    try {
      final total = _computeTotal();
      for (final line in validLines) {
        final tracking = line.tracking;
        final qty = double.tryParse(line.qty.text.trim()) ?? 0;
        if (tracking == null || (tracking.barcodeId ?? 0) <= 0) {
          throw StateError(
            'Configure variation / tracking for ${line.product!.name}',
          );
        }
        if (tracking.isSerialized) {
          if (qty != qty.roundToDouble() ||
              tracking.serialNumbers.length != qty.round()) {
            throw StateError(
              'Serial count must match quantity for ${line.product!.name}',
            );
          }
        }
        if (tracking.trackingType == 'BATCH' &&
            (tracking.batchNumber ?? '').trim().isEmpty) {
          throw StateError(
            'Batch / expiry details are required for ${line.product!.name}',
          );
        }
      }
      double? paidAmount;
      int? methodId;
      if (_paidNow) {
        paidAmount = double.tryParse(_paidAmount.text.trim()) ?? 0;
        methodId = _paymentMethodId;
        if (paidAmount <= 0) {
          throw StateError('Enter a valid paid amount');
        }
        if (paidAmount > total) {
          throw StateError('Paid amount cannot exceed total');
        }
        if (methodId == null) {
          throw StateError('Select a payment method');
        }
      }
      final repo = ref.read(grnRepositoryProvider);
      final headerAdjustments = _headerAdjustments
          .map((row) => row.toDraft())
          .whereType<CostAdjustmentDraft>()
          .toList();
      final itemAdjustments = <int, List<CostAdjustmentDraft>>{};
      final items = [
        for (int index = 0; index < validLines.length; index++)
          () {
            final l = validLines[index];
            final drafts = l.adjustments
                .map((row) => row.toDraft())
                .whereType<CostAdjustmentDraft>()
                .toList();
            if (drafts.isNotEmpty) {
              itemAdjustments[index] = drafts;
            }
            return GrnCreateItem(
              productId: l.product!.productId,
              quantity: double.tryParse(l.qty.text.trim()) ?? 0,
              unitPrice: double.tryParse(l.price.text.trim()) ?? 0,
              barcodeId: l.tracking?.barcodeId,
              serialNumbers: l.tracking?.serialNumbers ?? const [],
              batchNumber: l.tracking?.batchNumber,
              expiryDate: l.tracking?.expiryDate,
            );
          }(),
      ];
      await repo.createGrnWithoutPo(
        supplierId: supplierId,
        items: items,
        headerAdjustments: headerAdjustments,
        itemAdjustments: itemAdjustments,
        invoiceNumber: _invoiceNumber.text.trim().isEmpty
            ? null
            : _invoiceNumber.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        invoiceFilePath: _invoiceFilePath,
        paidAmount: paidAmount,
        paymentMethodId: methodId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on OutboxQueuedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _configureTracking(_GrnLine line) async {
    final product = line.product;
    if (product == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select a product first')),
        );
      return;
    }
    final qty = double.tryParse(line.qty.text.trim()) ?? 0;
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
      mode: InventoryTrackingMode.receive,
      initialSelection: line.tracking,
    );
    if (selection != null && mounted) {
      setState(() => line.tracking = selection);
    }
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
    String q = '';
    int? selected = supplierId;
    if (!context.mounted) return null;
    return showDialog<(int, String)?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Supplier',
          maxWidth: 720,
          searchField: TextField(
            decoration: const InputDecoration(
              hintText: 'Search suppliers',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (v) async {
              q = v.trim();
              try {
                final list =
                    await repo.getSuppliers(search: q.isEmpty ? null : q);
                setInner(() => results = list);
              } catch (_) {}
            },
          ),
          body: results.isEmpty
              ? const Center(child: Text('No suppliers'))
              : RadioGroup<int>(
                  groupValue: selected,
                  onChanged: (value) => setInner(() => selected = value),
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final s = results[i];
                      return RadioListTile<int>(
                        value: s.supplierId,
                        title: Text(s.name),
                        subtitle: Text(
                          [(s.phone ?? ''), (s.email ?? '')]
                              .where((e) => e.isNotEmpty)
                              .join(' • '),
                        ),
                      );
                    },
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
                            isMercantile: true,
                            isNonMercantile: false,
                            isActive: true,
                            totalPurchases: 0,
                            totalReturns: 0,
                            outstandingAmount: 0,
                            lastPurchaseDate: null,
                          )
                        : results.first);
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

class _GrnLine {
  InventoryListItem? product;
  InventoryTrackingSelection? tracking;
  final qty = TextEditingController();
  final price = TextEditingController();
  final adjustments = <EditableCostAdjustmentRow>[];
  void dispose() {
    for (final adjustment in adjustments) {
      adjustment.dispose();
    }
    qty.dispose();
    price.dispose();
  }
}

class _LineProductPicker extends ConsumerStatefulWidget {
  const _LineProductPicker({required this.line});
  final _GrnLine line;

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
          InventoryTrackingSelection? tracking;
          try {
            final variants = await ref
                .read(inventoryRepositoryProvider)
                .getStockVariants(picked.productId);
            if (variants.isNotEmpty) {
              final v = variants.first;
              tracking = InventoryTrackingSelection(
                barcodeId: v.barcodeId,
                trackingType: v.trackingType,
                isSerialized: v.isSerialized,
                barcode: v.barcode,
                variantName: v.variantName,
              );
            }
          } catch (_) {}
          setState(() {
            widget.line.product = picked;
            widget.line.tracking = tracking;
          });
        }
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
                p == null
                    ? 'Tap to select a product'
                    : [
                        p.name,
                        if ((widget.line.tracking?.variantName ?? '')
                            .trim()
                            .isNotEmpty)
                          widget.line.tracking!.variantName!.trim(),
                        if ((p.sku ?? '').isNotEmpty) 'SKU: ${p.sku}',
                      ].join(' • '),
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
    List<InventoryListItem> initial = [];
    try {
      initial = await repo.getStock();
    } catch (_) {}
    List<InventoryListItem> results = List.of(initial);
    int? selectedId = widget.line.product?.productId;
    if (!context.mounted) return null;
    return showDialog<InventoryListItem?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Product',
          maxWidth: 720,
          searchField: TextField(
            decoration: const InputDecoration(
              hintText: 'Search by name or SKU',
              prefixIcon: Icon(Icons.search_rounded),
            ),
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
          body: results.isEmpty
              ? const Center(child: Text('No products'))
              : RadioGroup<int>(
                  groupValue: selectedId,
                  onChanged: (value) => setInner(() => selectedId = value),
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (context, i) {
                      final it = results[i];
                      return RadioListTile<int>(
                        value: it.productId,
                        title: Text(it.name),
                        subtitle: Text([
                          if ((it.sku ?? '').isNotEmpty) 'SKU: ${it.sku}',
                          'Stock: ${it.stock.toStringAsFixed(2)}'
                        ].join(' • ')),
                      );
                    },
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
                    price: null,
                  ),
                );
                Navigator.pop(context, it.productId == -1 ? null : it);
              },
              child: const Text('Select'),
            )
          ],
        ),
      ),
    );
  }
}
