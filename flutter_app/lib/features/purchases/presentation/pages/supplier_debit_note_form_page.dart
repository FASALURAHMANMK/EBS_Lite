import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../../suppliers/data/models.dart';
import '../../../suppliers/data/supplier_repository.dart';
import '../../data/purchases_repository.dart';

class SupplierDebitNoteFormPage extends ConsumerStatefulWidget {
  const SupplierDebitNoteFormPage({super.key});

  @override
  ConsumerState<SupplierDebitNoteFormPage> createState() =>
      _SupplierDebitNoteFormPageState();
}

class _SupplierDebitNoteFormPageState
    extends ConsumerState<SupplierDebitNoteFormPage> {
  SupplierDto? _supplier;
  Map<String, dynamic>? _purchase;
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  bool _loadingPurchase = false;
  final List<_DebitNoteLineDraft> _lines = [];

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _pickSupplier() async {
    final repo = ref.read(supplierRepositoryProvider);
    List<SupplierDto> results = [];
    try {
      results = await repo.getSuppliers(isMercantile: true);
    } catch (_) {}
    int? selected = _supplier?.supplierId;
    if (!mounted) return;
    final picked = await showDialog<SupplierDto?>(
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
            onChanged: (value) async {
              try {
                final list = await repo.getSuppliers(
                  search: value.trim().isEmpty ? null : value.trim(),
                  isMercantile: true,
                );
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
                    itemBuilder: (context, index) {
                      final supplier = results[index];
                      return RadioListTile<int>(
                        value: supplier.supplierId,
                        title: Text(supplier.name),
                        subtitle: Text(
                          [
                            if ((supplier.phone ?? '').isNotEmpty)
                              supplier.phone!,
                            if ((supplier.email ?? '').isNotEmpty)
                              supplier.email!,
                          ].join(' • '),
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final supplier = results.firstWhere(
                  (item) => item.supplierId == selected,
                  orElse: () => SupplierDto(
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
                    totalDebitNotes: 0,
                    outstandingAmount: 0,
                    lastPurchaseDate: null,
                  ),
                );
                Navigator.pop(
                  context,
                  supplier.supplierId > 0 ? supplier : null,
                );
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() {
      _supplier = picked;
      _purchase = null;
      for (final line in _lines) {
        line.dispose();
      }
      _lines.clear();
    });
  }

  Future<void> _pickPurchase() async {
    final supplier = _supplier;
    if (supplier == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select a supplier first')),
        );
      return;
    }
    final repo = ref.read(supplierRepositoryProvider);
    List<Map<String, dynamic>> purchases = [];
    try {
      purchases = await repo.getOutstandingPurchases(
        supplierId: supplier.supplierId,
      );
    } catch (_) {}
    int? selectedId = _purchase?['purchase_id'] as int?;
    if (!mounted) return;
    final picked = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInner) => AppSelectionDialog(
          title: 'Select Purchase',
          maxWidth: 720,
          body: purchases.isEmpty
              ? const Center(child: Text('No purchases'))
              : RadioGroup<int>(
                  groupValue: selectedId,
                  onChanged: (value) => setInner(() => selectedId = value),
                  child: ListView.builder(
                    itemCount: purchases.length,
                    itemBuilder: (context, index) {
                      final purchase = purchases[index];
                      final totalAmount =
                          (purchase['total_amount'] as num?)?.toDouble() ?? 0;
                      final paidAmount =
                          (purchase['paid_amount'] as num?)?.toDouble() ?? 0;
                      final balance = totalAmount - paidAmount;
                      return RadioListTile<int>(
                        value: purchase['purchase_id'] as int? ?? 0,
                        title: Text(
                          purchase['purchase_number']?.toString() ?? '',
                        ),
                        subtitle: Text(
                          'Balance: ${balance.toStringAsFixed(2)}',
                        ),
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final purchase = purchases.firstWhere(
                  (item) => item['purchase_id'] == selectedId,
                  orElse: () => const {},
                );
                Navigator.pop(
                  context,
                  purchase.isEmpty ? null : purchase,
                );
              },
              child: const Text('Select'),
            ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _loadPurchaseDetails(picked['purchase_id'] as int? ?? 0);
  }

  Future<void> _loadPurchaseDetails(int purchaseId) async {
    setState(() => _loadingPurchase = true);
    try {
      final purchase =
          await ref.read(purchasesRepositoryProvider).getPurchase(purchaseId);
      for (final line in _lines) {
        line.dispose();
      }
      final details =
          (purchase['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      _lines
        ..clear()
        ..addAll(
          details
              .where(
                (detail) =>
                    ((detail['received_quantity'] as num?)?.toDouble() ?? 0) >
                    0,
              )
              .map(_DebitNoteLineDraft.fromDetail),
        );
      if (!mounted) return;
      setState(() => _purchase = purchase);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(ErrorHandler.message(e))));
    } finally {
      if (mounted) setState(() => _loadingPurchase = false);
    }
  }

  Future<void> _configureTracking(_DebitNoteLineDraft line) async {
    final qty = double.tryParse(line.quantity.text.trim()) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Enter a quantity first')),
        );
      return;
    }
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: line.productId,
      productName: line.productName,
      quantity: qty,
      mode: InventoryTrackingMode.issue,
      initialSelection: line.tracking,
    );
    if (selection != null && mounted) {
      setState(() => line.tracking = selection);
    }
  }

  Future<void> _submit() async {
    final supplier = _supplier;
    final purchase = _purchase;
    if (supplier == null || purchase == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select supplier and purchase')),
        );
      return;
    }

    final itemPayload = <Map<String, dynamic>>[];
    for (final line in _lines.where((line) => line.selected)) {
      final label = line.label.text.trim();
      if (label.isEmpty) {
        throw StateError('Enter a label for ${line.productName}');
      }
      if (line.stockAction == 'COST_ONLY') {
        final amount = double.tryParse(line.amount.text.trim()) ?? 0;
        if (amount <= 0) {
          throw StateError(
              'Enter a cost reduction amount for ${line.productName}');
        }
        itemPayload.add({
          'purchase_detail_id': line.purchaseDetailId,
          'product_id': line.productId,
          'label': label,
          'stock_action': line.stockAction,
          'amount': amount,
        });
      } else {
        final qty = double.tryParse(line.quantity.text.trim()) ?? 0;
        if (qty <= 0) {
          throw StateError(
              'Enter a stock reduction quantity for ${line.productName}');
        }
        if (line.tracking == null) {
          throw StateError(
            'Configure tracking / variation for ${line.productName}',
          );
        }
        itemPayload.add({
          'purchase_detail_id': line.purchaseDetailId,
          'product_id': line.productId,
          'barcode_id': line.tracking?.barcodeId,
          'label': label,
          'stock_action': line.stockAction,
          'quantity': qty,
          ...line.tracking!.toIssueJson(),
        });
      }
    }
    if (itemPayload.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Select at least one line')),
        );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(purchasesRepositoryProvider).createSupplierDebitNote(
            supplierId: supplier.supplierId,
            purchaseId: purchase['purchase_id'] as int? ?? 0,
            items: itemPayload,
            referenceNumber:
                _reference.text.trim().isEmpty ? null : _reference.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Supplier Debit Note')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Supplier'),
              subtitle: Text(_supplier?.name ?? 'Select supplier'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _pickSupplier,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Purchase'),
              subtitle: Text(
                _purchase?['purchase_number']?.toString() ?? 'Select purchase',
              ),
              trailing: _loadingPurchase
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: _pickPurchase,
            ),
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Reference',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.description_outlined),
              ),
            ),
            const SizedBox(height: 12),
            if (_lines.isEmpty)
              const Card(
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Select a purchase with received items'),
                ),
              )
            else
              ..._lines.map(
                (line) => Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: line.selected,
                          onChanged: (value) =>
                              setState(() => line.selected = value ?? false),
                          title: Text(line.productName),
                          subtitle: Text(
                            'Received: ${line.receivedQuantity.toStringAsFixed(2)}',
                          ),
                        ),
                        TextField(
                          controller: line.label,
                          decoration: const InputDecoration(
                            labelText: 'Label',
                            prefixIcon: Icon(Icons.label_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: line.stockAction,
                          items: const [
                            DropdownMenuItem(
                              value: 'COST_ONLY',
                              child: Text('Reduce Cost Only'),
                            ),
                            DropdownMenuItem(
                              value: 'REDUCE_STOCK',
                              child: Text('Reduce Stock'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => line.stockAction = value);
                          },
                          decoration: const InputDecoration(
                            labelText: 'Action',
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (line.stockAction == 'COST_ONLY')
                          TextField(
                            controller: line.amount,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Cost Reduction Amount',
                              prefixIcon: Icon(Icons.currency_exchange_rounded),
                            ),
                          )
                        else ...[
                          TextField(
                            controller: line.quantity,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Reduce Quantity',
                              prefixIcon:
                                  Icon(Icons.format_list_numbered_rounded),
                            ),
                          ),
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
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Text('Create Supplier Debit Note'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebitNoteLineDraft {
  _DebitNoteLineDraft({
    required this.purchaseDetailId,
    required this.productId,
    required this.productName,
    required this.receivedQuantity,
  })  : label = TextEditingController(text: 'Supplier debit note'),
        amount = TextEditingController(),
        quantity = TextEditingController();

  factory _DebitNoteLineDraft.fromDetail(Map<String, dynamic> detail) {
    return _DebitNoteLineDraft(
      purchaseDetailId: detail['purchase_detail_id'] as int? ?? 0,
      productId: detail['product_id'] as int? ?? 0,
      productName: detail['product']?['name']?.toString() ??
          'Product #${detail['product_id']}',
      receivedQuantity: (detail['received_quantity'] as num?)?.toDouble() ?? 0,
    );
  }

  final int purchaseDetailId;
  final int productId;
  final String productName;
  final double receivedQuantity;
  bool selected = false;
  String stockAction = 'COST_ONLY';
  final TextEditingController label;
  final TextEditingController amount;
  final TextEditingController quantity;
  InventoryTrackingSelection? tracking;

  void dispose() {
    label.dispose();
    amount.dispose();
    quantity.dispose();
  }
}
