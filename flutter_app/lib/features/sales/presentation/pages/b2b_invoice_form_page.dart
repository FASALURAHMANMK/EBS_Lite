import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error_handler.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../../shared/widgets/sales_action_password_dialog.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../../dashboard/data/payment_methods_repository.dart';
import '../../../inventory/data/inventory_repository.dart';
import '../../../inventory/data/models.dart';
import '../../../inventory/presentation/widgets/inventory_tracking_selector.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';
import '../widgets/professional_document_widgets.dart';
import 'sale_detail_page.dart';

class B2BInvoiceFormPage extends ConsumerStatefulWidget {
  const B2BInvoiceFormPage(
      {super.key, this.sale, this.exchangeItems = const []});

  final SaleDto? sale;
  final List<SaleItemDto> exchangeItems;

  bool get isEdit => sale != null && exchangeItems.isEmpty;
  bool get isExchange => sale != null && exchangeItems.isNotEmpty;

  @override
  ConsumerState<B2BInvoiceFormPage> createState() => _B2BInvoiceFormPageState();
}

class _B2BInvoiceFormPageState extends ConsumerState<B2BInvoiceFormPage> {
  final _discountCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();

  PosCustomerDto? _customer;
  PaymentMethodDto? _paymentMethod;
  List<_InvoiceLine> _lines = [_InvoiceLine.empty()];
  bool _saving = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    final sale = widget.sale;
    if (sale != null) {
      _customer =
          sale.customerId != null && (sale.customerName ?? '').trim().isNotEmpty
              ? PosCustomerDto(
                  customerId: sale.customerId!,
                  name: sale.customerName!,
                  customerType: 'B2B')
              : null;
      if (sale.paymentMethodId != null &&
          (sale.paymentMethodName ?? '').trim().isNotEmpty) {
        _paymentMethod = PaymentMethodDto(
          methodId: sale.paymentMethodId!,
          name: sale.paymentMethodName!,
          type: 'OTHER',
          isActive: true,
        );
      }
      _discountCtrl.text = sale.discountAmount.toStringAsFixed(2);
      _paidCtrl.text = sale.paidAmount.toStringAsFixed(2);
      _notesCtrl.text = sale.notes ?? '';
      if (widget.isEdit) {
        _lines = sale.items
            .where((e) =>
                ((e.productId ?? 0) > 0 || (e.comboProductId ?? 0) > 0) &&
                e.quantity > 0)
            .map(_InvoiceLine.fromSaleItem)
            .toList();
        if (_lines.isEmpty) _lines = [_InvoiceLine.empty()];
        _info = 'Editing ${sale.saleNumber} in a document-style B2B form.';
      } else if (widget.isExchange) {
        _lines = widget.exchangeItems
            .map((e) => _InvoiceLine.fromExchangeItem(sale, e))
            .toList();
        _lines.add(_InvoiceLine.empty());
        _paidCtrl.text = '0';
        _info =
            'Exchange draft for ${sale.saleNumber}. Refund and replacement lines stay in one business document.';
      }
    }
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  String get _title => widget.isEdit
      ? 'Edit B2B Invoice'
      : widget.isExchange
          ? 'B2B Exchange Invoice'
          : 'New B2B Invoice';

  List<_InvoiceLine> get _activeLines => _lines
      .where((e) => e.hasProduct && e.unitPrice > 0 && e.quantity != 0)
      .toList(growable: false);

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
                results = await repo.searchCustomers(q, customerType: 'B2B');
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
              maxWidth: 520,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Search B2B parties',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => doSearch(v.trim()),
                onSubmitted: (v) => doSearch(v.trim()),
              ),
              body: results.isEmpty && !loading
                  ? const Center(child: Text('No B2B parties found'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final item = results[i];
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
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
    if (result != null && mounted) setState(() => _customer = result);
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
    if (result != null && mounted) setState(() => _paymentMethod = result);
  }

  Future<InventoryListItem?> _pickProduct() async {
    return showDialog<InventoryListItem>(
      context: context,
      builder: (context) {
        final repo = ref.read(inventoryRepositoryProvider);
        final controller = TextEditingController();
        List<InventoryListItem> results = const [];
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

            return AppSelectionDialog(
              title: 'Add Product',
              maxWidth: 640,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: 'Search products / variants / barcode',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => doSearch(v.trim()),
                onSubmitted: (v) => doSearch(v.trim()),
              ),
              body: results.isEmpty && !loading
                  ? const Center(child: Text('No products found'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final item = results[i];
                        return ListTile(
                          title: Text(item.name),
                          subtitle: Text([
                            if ((item.variantName ?? '').trim().isNotEmpty)
                              item.variantName!,
                            'Stock ${item.stock.toStringAsFixed(2)}',
                            'Price ${(item.price ?? 0).toStringAsFixed(2)}',
                          ].join(' • ')),
                          onTap: () => Navigator.of(context).pop(item),
                        );
                      },
                    ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel')),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addOrReplaceProduct([_InvoiceLine? target]) async {
    final picked = await _pickProduct();
    if (picked == null || !mounted) return;
    setState(() {
      if (target != null) {
        target.applyProduct(picked);
        return;
      }
      final blankIndex =
          _lines.indexWhere((e) => !e.hasProduct && !e.hasValues);
      if (blankIndex >= 0) {
        _lines[blankIndex].applyProduct(picked);
      } else {
        _lines = [..._lines, _InvoiceLine.fromInventory(picked)];
      }
    });
  }

  Future<void> _configureTracking(_InvoiceLine line) async {
    if (!line.requiresTracking || (line.productId ?? 0) <= 0) return;
    final qty = line.quantity.abs();
    if (qty <= 0) {
      setState(() => _error = 'Enter quantity first for ${line.displayName}.');
      return;
    }
    final selection = await showInventoryTrackingSelector(
      context: context,
      ref: ref,
      productId: line.productId!,
      productName: line.displayName,
      quantity: qty,
      mode: InventoryTrackingMode.issue,
      initialSelection: line.tracking,
    );
    if (selection != null && mounted) setState(() => line.tracking = selection);
  }

  Future<void> _submit() async {
    final customer = _customer;
    if (customer == null) {
      setState(() => _error = 'Select a B2B party before saving.');
      return;
    }
    final lines = _activeLines;
    if (lines.isEmpty) {
      setState(() => _error = 'Add at least one invoice line.');
      return;
    }
    for (final line in lines) {
      if (line.requiresTracking && line.tracking == null) {
        setState(() => _error = 'Configure tracking for ${line.displayName}.');
        return;
      }
    }
    final paidAmount = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    if (paidAmount > 0 && _paymentMethod == null) {
      setState(() =>
          _error = 'Select a payment method when paid amount is entered.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.isEdit) {
        final salesActionPassword = await showSalesActionPasswordDialog(
          context,
          title: 'Authorize Invoice Edit',
          message:
              'Enter the separate edit/refund PIN or password configured for your user.',
          actionLabel: 'Authorize',
        );
        if (!mounted || salesActionPassword == null) return;
        final result = await ref.read(posRepositoryProvider).editSale(
              baseline: widget.sale!,
              transactionType: 'B2B',
              customerId: customer.customerId,
              items:
                  lines.map((e) => e.toPosCartItem()).toList(growable: false),
              paymentMethodId: _paymentMethod?.methodId,
              paidAmount: paidAmount,
              discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
              notes: _notesCtrl.text.trim(),
              salesActionPassword: salesActionPassword,
            );
        if (!mounted) return;
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) => SaleDetailPage(saleId: result.saleId)),
        );
        return;
      }

      String? overridePassword;
      if (lines.any((e) => e.quantity < 0)) {
        overridePassword = await showSalesActionPasswordDialog(
          context,
          title: 'Authorize Refund Lines',
          message:
              'Enter the separate edit/refund PIN or password configured for your user.',
          actionLabel: 'Authorize',
        );
        if (!mounted || overridePassword == null) return;
      }

      final saleId = await ref.read(salesRepositoryProvider).createInvoice(
            customerId: customer.customerId,
            items: lines.map((e) => e.toCreateJson()).toList(growable: false),
            paymentMethodId: _paymentMethod?.methodId,
            paidAmount: paidAmount,
            discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
            notes: _notesCtrl.text.trim(),
            transactionType: 'B2B',
            overridePassword: overridePassword,
          );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => SaleDetailPage(saleId: saleId)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 1080;
    final location = ref.watch(locationNotifierProvider).selected;
    final lines = _activeLines;
    final lineNet = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final paid = double.tryParse(_paidCtrl.text.trim()) ?? 0;
    final total = lineNet - discount;
    final summary = ProfessionalSummaryCard(
      title: 'Document Summary',
      rows: [
        (label: 'Active Lines', value: '${lines.length}', emphasize: false),
        (
          label: 'Line Net',
          value: lineNet.toStringAsFixed(2),
          emphasize: false
        ),
        (
          label: 'Header Discount',
          value: discount.toStringAsFixed(2),
          emphasize: false
        ),
        (
          label: 'Paid Amount',
          value: paid.toStringAsFixed(2),
          emphasize: false
        ),
        (
          label: 'Estimated Total',
          value: total.toStringAsFixed(2),
          emphasize: true
        ),
        (
          label: 'Balance',
          value: (total - paid).toStringAsFixed(2),
          emphasize: true
        ),
      ],
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: Icon(widget.isEdit
              ? Icons.save_as_rounded
              : Icons.receipt_long_rounded),
          label: Text(
            _saving
                ? 'Saving...'
                : widget.isEdit
                    ? 'Save Invoice Changes'
                    : widget.isExchange
                        ? 'Create Exchange Invoice'
                        : 'Create B2B Invoice',
          ),
        ),
      ),
    );

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: _title,
          subtitle: widget.isExchange
              ? 'Use a proper business document for B2B refund and replacement work instead of the POS checkout surface.'
              : 'Structured B2B invoice entry with party selection, commercial terms, dense line rows, and a business-document summary.',
          badges: [
            const ProfessionalBadge(label: 'B2B Document'),
            if (widget.isEdit)
              const ProfessionalBadge(
                label: 'Edit Mode',
                backgroundColor: Color(0xFFF8EEDC),
                foregroundColor: Color(0xFF7B5416),
              ),
            if (widget.isExchange)
              const ProfessionalBadge(
                label: 'Exchange Draft',
                backgroundColor: Color(0xFFFDE8E4),
                foregroundColor: Color(0xFF8A3E31),
              ),
            if (location != null)
              ProfessionalBadge(
                label: 'Location: ${location.name}',
                backgroundColor: const Color(0xFFE8F3EC),
                foregroundColor: const Color(0xFF255C35),
              ),
          ],
        ),
        if ((_error ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _Banner(
              message: _error!,
              color: Theme.of(context).colorScheme.errorContainer),
        ],
        if ((_info ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _Banner(message: _info!, color: const Color(0xFFE7F0FA)),
        ],
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Party & Terms',
          subtitle:
              'Keep party identity, payment collection, and document notes in one structured section.',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: wide ? 360 : double.infinity,
                child: _PartyBox(
                    customer: _customer,
                    onSelect: _saving ? null : _pickCustomer),
              ),
              SizedBox(
                width: wide ? 220 : double.infinity,
                child: TextField(
                  controller: _discountCtrl,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Header Discount',
                      prefixIcon: Icon(Icons.percent_rounded)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: wide ? 220 : double.infinity,
                child: TextField(
                  controller: _paidCtrl,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Paid Amount',
                      prefixIcon: Icon(Icons.payments_outlined)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: wide ? 260 : double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _pickPaymentMethod,
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  label: Text(
                    _paymentMethod == null
                        ? 'Select Payment Method'
                        : 'Payment: ${_paymentMethod!.name}',
                  ),
                ),
              ),
              SizedBox(
                width: wide ? 480 : double.infinity,
                child: TextField(
                  controller: _notesCtrl,
                  enabled: !_saving,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: widget.sale == null
                        ? 'Notes / Internal Remarks'
                        : 'Notes / Internal Remarks ${widget.sale!.saleNumber.isNotEmpty ? "for ${widget.sale!.saleNumber}" : ""}',
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Invoice Lines',
          subtitle:
              'A denser, professional line-entry grid for B2B operations.',
          action: FilledButton.tonalIcon(
            onPressed: _saving ? null : _addOrReplaceProduct,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Item'),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7FB),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: const [
                      _Head(label: 'Item', width: 320),
                      _Head(label: 'Qty', width: 90),
                      _Head(label: 'Price', width: 110),
                      _Head(label: 'Disc %', width: 90),
                      _Head(label: 'Net', width: 110),
                      _Head(label: 'Tracking', width: 110),
                      _Head(label: 'Action', width: 70),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                for (final line in _lines) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 320,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(line.displayName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _addOrReplaceProduct(line),
                                    child: Text(
                                        line.hasProduct ? 'Change' : 'Select'),
                                  ),
                                  if (line.quantity < 0)
                                    const ProfessionalBadge(
                                      label: 'Refund',
                                      backgroundColor: Color(0xFFFDE8E4),
                                      foregroundColor: Color(0xFF8A3E31),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _NumCell(
                            controller: line.quantityCtrl,
                            width: 90,
                            enabled: !line.lockedQuantity,
                            onChanged: (_) => setState(() {})),
                        _NumCell(
                            controller: line.priceCtrl,
                            width: 110,
                            onChanged: (_) => setState(() {})),
                        _NumCell(
                            controller: line.discountCtrl,
                            width: 90,
                            onChanged: (_) => setState(() {})),
                        SizedBox(
                          width: 110,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text(line.lineTotal.toStringAsFixed(2),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: line.requiresTracking
                              ? OutlinedButton(
                                  onPressed: _saving
                                      ? null
                                      : () => _configureTracking(line),
                                  child: Text(
                                      line.tracking == null ? 'Set' : 'Ready'),
                                )
                              : const Padding(
                                  padding: EdgeInsets.only(top: 14),
                                  child: Text('N/A'),
                                ),
                        ),
                        SizedBox(
                          width: 70,
                          child: IconButton(
                            onPressed: _saving
                                ? null
                                : () {
                                    setState(() {
                                      line.dispose();
                                      _lines = [..._lines]..remove(line);
                                      if (_lines.isEmpty) {
                                        _lines = [_InvoiceLine.empty()];
                                      }
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
        if (!wide) ...[
          const SizedBox(height: 16),
          summary,
        ],
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SafeArea(
        child: wide
            ? Row(
                children: [
                  Expanded(child: content),
                  SizedBox(
                    width: 340,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                      child: ListView(children: [summary]),
                    ),
                  ),
                ],
              )
            : content,
      ),
    );
  }
}

class _InvoiceLine {
  _InvoiceLine({
    this.productId,
    this.comboProductId,
    this.barcodeId,
    this.productName,
    this.variantName,
    this.trackingType = 'VARIANT',
    this.sourceSaleDetailId,
    this.tracking,
    this.comboTracking = const [],
    String quantity = '',
    String price = '',
    String discount = '0',
  })  : quantityCtrl = TextEditingController(text: quantity),
        priceCtrl = TextEditingController(text: price),
        discountCtrl = TextEditingController(text: discount);

  factory _InvoiceLine.empty() => _InvoiceLine();

  factory _InvoiceLine.fromInventory(InventoryListItem item) => _InvoiceLine(
        productId: item.productId > 0 ? item.productId : null,
        comboProductId: item.comboProductId,
        barcodeId: item.barcodeId,
        productName: item.name,
        variantName: item.variantName,
        trackingType: item.trackingType,
        quantity: '1',
        price: (item.price ?? 0).toStringAsFixed(2),
      );

  factory _InvoiceLine.fromSaleItem(SaleItemDto item) => _InvoiceLine(
        productId: item.productId,
        comboProductId: item.comboProductId,
        barcodeId: item.barcodeId,
        productName: item.productName,
        variantName: item.variantName,
        trackingType: item.trackingType,
        sourceSaleDetailId: item.sourceSaleDetailId,
        comboTracking: item.comboComponentTracking,
        tracking: item.isSerialized || item.trackingType == 'BATCH'
            ? InventoryTrackingSelection(
                barcodeId: item.barcodeId,
                trackingType: item.trackingType,
                isSerialized: item.isSerialized,
                barcode: item.barcode,
                variantName: item.variantName,
                serialNumbers: item.serialNumbers,
              )
            : null,
        quantity: item.quantity.toStringAsFixed(2),
        price: item.unitPrice.toStringAsFixed(2),
        discount: item.discountPercent.toStringAsFixed(2),
      );

  factory _InvoiceLine.fromExchangeItem(SaleDto sale, SaleItemDto item) {
    final line = _InvoiceLine.fromSaleItem(item);
    line.sourceSaleDetailId ??= item.saleDetailId;
    line.lockedQuantity = true;
    line.quantityCtrl.text = (-item.quantity.abs()).toStringAsFixed(2);
    line.productName ??= 'Refund from ${sale.saleNumber}';
    return line;
  }

  int? productId;
  int? comboProductId;
  int? barcodeId;
  String? productName;
  String? variantName;
  String trackingType;
  int? sourceSaleDetailId;
  bool lockedQuantity = false;
  InventoryTrackingSelection? tracking;
  List<PosComboComponentTracking> comboTracking;
  final TextEditingController quantityCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController discountCtrl;

  bool get hasProduct => (productId ?? 0) > 0 || (comboProductId ?? 0) > 0;
  bool get hasValues =>
      quantityCtrl.text.trim().isNotEmpty ||
      priceCtrl.text.trim().isNotEmpty ||
      (productName ?? '').trim().isNotEmpty;
  double get quantity => double.tryParse(quantityCtrl.text.trim()) ?? 0;
  double get unitPrice => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get discount => double.tryParse(discountCtrl.text.trim()) ?? 0;
  bool get requiresTracking =>
      trackingType == 'BATCH' || trackingType == 'SERIAL';
  double get lineTotal =>
      (quantity * unitPrice) -
      ((quantity * unitPrice) * (discount.clamp(0.0, 100.0) / 100.0));
  String get displayName => [
        (productName ?? '').trim().isEmpty ? null : productName!.trim(),
        (variantName ?? '').trim().isEmpty ? null : variantName!.trim(),
      ].whereType<String>().join(' • ').isEmpty
          ? 'Select product'
          : [
              (productName ?? '').trim().isEmpty ? null : productName!.trim(),
              (variantName ?? '').trim().isEmpty ? null : variantName!.trim(),
            ].whereType<String>().join(' • ');

  void applyProduct(InventoryListItem item) {
    productId = item.productId > 0 ? item.productId : null;
    comboProductId = item.comboProductId;
    barcodeId = item.barcodeId;
    productName = item.name;
    variantName = item.variantName;
    trackingType = item.trackingType;
    sourceSaleDetailId = null;
    tracking = null;
    comboTracking = const [];
    lockedQuantity = false;
    quantityCtrl.text = '1';
    priceCtrl.text = (item.price ?? 0).toStringAsFixed(2);
    discountCtrl.text = '0';
  }

  PosCartItem toPosCartItem() => PosCartItem(
        product: PosProductDto(
          productId: productId ?? 0,
          comboProductId: comboProductId,
          barcodeId: barcodeId ?? 0,
          name: productName ?? 'Item',
          price: unitPrice,
          stock: 0,
          variantName: variantName,
          isVirtualCombo: (comboProductId ?? 0) > 0,
          trackingType: trackingType,
          isSerialized: trackingType == 'SERIAL',
        ),
        quantity: quantity,
        unitPrice: unitPrice,
        discountPercent: discount,
        sourceSaleDetailId: sourceSaleDetailId,
        tracking: tracking,
        comboTracking: comboTracking,
        lockedQuantity: lockedQuantity,
      );

  Map<String, dynamic> toCreateJson() => {
        if ((productId ?? 0) > 0) 'product_id': productId,
        if ((comboProductId ?? 0) > 0) 'combo_product_id': comboProductId,
        if ((barcodeId ?? 0) > 0) 'barcode_id': barcodeId,
        if ((sourceSaleDetailId ?? 0) > 0)
          'source_sale_detail_id': sourceSaleDetailId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percentage': discount,
        if (tracking != null) ...tracking!.toIssueJson(),
        if (comboTracking.isNotEmpty)
          'combo_component_tracking':
              comboTracking.map((e) => e.toJson()).toList(),
      };

  void dispose() {
    quantityCtrl.dispose();
    priceCtrl.dispose();
    discountCtrl.dispose();
  }
}

class _PartyBox extends StatelessWidget {
  const _PartyBox({required this.customer, required this.onSelect});

  final PosCustomerDto? customer;
  final VoidCallback? onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E3EF)),
      ),
      child: Row(
        children: [
          const Icon(Icons.business_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              customer?.name ?? 'Select B2B Party',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.tonal(onPressed: onSelect, child: const Text('Select')),
        ],
      ),
    );
  }
}

class _Head extends StatelessWidget {
  const _Head({required this.label, required this.width});
  final String label;
  final double width;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Text(label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w800)),
      );
}

class _NumCell extends StatelessWidget {
  const _NumCell(
      {required this.controller,
      required this.width,
      this.enabled = true,
      required this.onChanged});
  final TextEditingController controller;
  final double width;
  final bool enabled;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: const TextInputType.numberWithOptions(
                decimal: true, signed: true),
            onChanged: onChanged,
          ),
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color});
  final String message;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(16)),
        child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
      );
}
