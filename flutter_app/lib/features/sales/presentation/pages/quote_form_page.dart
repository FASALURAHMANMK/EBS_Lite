import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';
import '../widgets/professional_document_widgets.dart';
import 'sale_detail_page.dart';

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
  String _transactionType = 'B2B';
  DateTime? _validUntil;
  List<_QuoteLine> _lines = [_QuoteLine.empty()];
  bool _loading = false;
  String? _error;
  String? _info;
  bool _readOnly = false;
  int? _convertedSaleId;

  bool get _isEdit => widget.quoteId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _loadQuote();
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _notesCtrl.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  List<_QuoteLine> get _activeLines => _lines
      .where((e) => e.hasProduct && e.unitPrice > 0 && e.quantity > 0)
      .toList(growable: false);

  Future<void> _loadQuote() async {
    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final quote =
          await ref.read(salesRepositoryProvider).getQuote(widget.quoteId!);
      final status = quote['status']?.toString() ?? 'DRAFT';
      _convertedSaleId = quote['converted_sale_id'] as int?;
      _readOnly = _convertedSaleId != null || status == 'CONVERTED';
      if (_readOnly) {
        _info = _convertedSaleId == null
            ? 'This quote is read-only because it has already been converted.'
            : 'This quote is read-only because it has already been converted to sale #$_convertedSaleId.';
      }
      _discountCtrl.text = ((quote['discount_amount'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(2);
      _notesCtrl.text = quote['notes']?.toString() ?? '';
      _transactionType =
          normalizeSaleTransactionType(quote['transaction_type']?.toString());
      final customer = quote['customer'] as Map<String, dynamic>?;
      if (customer != null) {
        _customer = PosCustomerDto(
          customerId: customer['customer_id'] as int? ?? 0,
          name: customer['name']?.toString() ?? '',
          customerType: normalizeSaleTransactionType(
              customer['customer_type']?.toString() ?? _transactionType),
          contactPerson: customer['contact_person']?.toString(),
          phone: customer['phone']?.toString(),
          email: customer['email']?.toString(),
        );
      }
      final validUntil = quote['valid_until']?.toString();
      _validUntil = validUntil == null ? null : DateTime.tryParse(validUntil);
      _lines = (quote['items'] as List<dynamic>? ?? [])
          .map((e) => _QuoteLine.fromJson(e as Map<String, dynamic>))
          .toList();
      if (_lines.isEmpty) _lines = [_QuoteLine.empty()];
    } catch (e) {
      _error = ErrorHandler.message(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _validUntil = picked);
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
                results = await repo.searchCustomers(
                  q,
                  customerType: _transactionType == 'B2B' ? 'B2B' : 'RETAIL',
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
              title: _transactionType == 'B2B'
                  ? 'Select B2B Party'
                  : 'Select Retail Customer',
              maxWidth: 520,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: _transactionType == 'B2B'
                      ? 'Search B2B parties'
                      : 'Search customers',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (v) => doSearch(v.trim()),
                onSubmitted: (v) => doSearch(v.trim()),
              ),
              body: results.isEmpty && !loading
                  ? Center(
                      child: Text(_transactionType == 'B2B'
                          ? 'No B2B parties'
                          : 'No customers'))
                  : ListView.builder(
                      itemCount: results.length,
                      itemBuilder: (context, i) {
                        final c = results[i];
                        return ListTile(
                          title: Text(c.name),
                          subtitle: Text([
                            if ((c.contactPerson ?? '').isNotEmpty)
                              c.contactPerson!,
                            if ((c.phone ?? '').isNotEmpty) c.phone!,
                            if ((c.email ?? '').isNotEmpty) c.email!,
                          ].join(' • ')),
                          onTap: () => Navigator.of(context).pop(c),
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

  Future<PosProductDto?> _pickProduct() async {
    return showDialog<PosProductDto>(
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

            return AppSelectionDialog(
              title: 'Add Item',
              maxWidth: 620,
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
                        final p = results[i];
                        return ListTile(
                          title: Text(p.name),
                          subtitle: Text([
                            if ((p.variantName ?? '').trim().isNotEmpty)
                              p.variantName!,
                            'Price ${p.price.toStringAsFixed(2)}',
                            if ((p.barcode ?? '').trim().isNotEmpty) p.barcode!,
                          ].join(' • ')),
                          onTap: () => Navigator.of(context).pop(p),
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

  Future<void> _addOrReplaceProduct([_QuoteLine? target]) async {
    final picked = await _pickProduct();
    if (picked == null || !mounted) return;
    setState(() {
      if (target != null) {
        target.applyProduct(picked);
        return;
      }
      final blank = _lines.indexWhere((e) => !e.hasProduct && !e.hasValues);
      if (blank >= 0) {
        _lines[blank].applyProduct(picked);
      } else {
        _lines = [..._lines, _QuoteLine.fromProduct(picked)];
      }
    });
  }

  Future<void> _submit() async {
    if (_readOnly) {
      setState(() => _error = 'This quote is read-only.');
      return;
    }
    final items = _activeLines;
    if (items.isEmpty) {
      setState(() => _error = 'Add at least one quote line.');
      return;
    }
    if (_transactionType == 'B2B' && _customer == null) {
      setState(() => _error = 'Select a B2B party for this quote.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payloadItems = items.map((e) => e.toJson()).toList(growable: false);
      final repo = ref.read(salesRepositoryProvider);
      if (_isEdit) {
        await repo.updateQuote(
          widget.quoteId!,
          customerId: _customer?.customerId,
          clearCustomer: _customer == null,
          transactionType: _transactionType,
          notes: _notesCtrl.text.trim(),
          validUntil: _validUntil,
          discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
          items: payloadItems,
        );
      } else {
        await repo.createQuote(
          customerId: _customer?.customerId,
          transactionType: _transactionType,
          validUntil: _validUntil,
          discountAmount: double.tryParse(_discountCtrl.text.trim()) ?? 0,
          notes: _notesCtrl.text.trim(),
          items: payloadItems,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localePrefs = ref.watch(localePreferencesProvider);
    final wide = MediaQuery.of(context).size.width >= 1080;
    final subtotal =
        _activeLines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final total = subtotal - discount;
    final summary = ProfessionalSummaryCard(
      title: 'Quote Summary',
      rows: [
        (label: 'Lines', value: '${_activeLines.length}', emphasize: false),
        (
          label: 'Line Net',
          value: subtotal.toStringAsFixed(2),
          emphasize: false
        ),
        (
          label: 'Header Discount',
          value: discount.toStringAsFixed(2),
          emphasize: false
        ),
        (
          label: 'Quoted Total',
          value: total.toStringAsFixed(2),
          emphasize: true
        ),
      ],
      footer: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: (_loading || _readOnly) ? null : _submit,
          icon: const Icon(Icons.request_quote_rounded),
          label: Text(_readOnly
              ? 'Read-only'
              : (_isEdit ? 'Update Quote' : 'Create Quote')),
        ),
      ),
    );

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ProfessionalDocumentHeader(
          title: _isEdit
              ? (_readOnly ? 'Quote (Read-only)' : 'Edit Quote')
              : 'New Quote',
          subtitle:
              'A cleaner ERP-style quote form with structured header details, a denser line grid, and a persistent summary panel.',
          badges: [
            ProfessionalBadge(
                label:
                    _transactionType == 'B2B' ? 'B2B Quote' : 'Retail Quote'),
            if (_readOnly)
              const ProfessionalBadge(
                label: 'Read-only',
                backgroundColor: Color(0xFFF8EEDC),
                foregroundColor: Color(0xFF7B5416),
              ),
          ],
        ),
        if ((_error ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _QuoteBanner(
              message: _error!,
              color: Theme.of(context).colorScheme.errorContainer),
        ],
        if ((_info ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _QuoteBanner(message: _info!, color: const Color(0xFFE7F0FA)),
        ],
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Quote Header',
          subtitle:
              'Keep party, validity, discount, and commercial notes in a standard business form layout.',
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(
                width: wide ? 220 : double.infinity,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(_transactionType),
                  initialValue: _transactionType,
                  decoration: const InputDecoration(labelText: 'Quote Type'),
                  items: const [
                    DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                    DropdownMenuItem(value: 'RETAIL', child: Text('Retail')),
                  ],
                  onChanged: (_loading || _readOnly)
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() {
                            _transactionType = value;
                            if (_customer != null &&
                                normalizeSaleTransactionType(
                                        _customer!.customerType) !=
                                    value) {
                              _customer = null;
                            }
                          });
                        },
                ),
              ),
              SizedBox(
                width: wide ? 360 : double.infinity,
                child: _QuotePartyBox(
                  customer: _customer,
                  label: _transactionType == 'B2B'
                      ? 'B2B Party'
                      : 'Retail Customer',
                  onSelect: (_loading || _readOnly) ? null : _pickCustomer,
                ),
              ),
              SizedBox(
                width: wide ? 240 : double.infinity,
                child: OutlinedButton.icon(
                  onPressed: (_loading || _readOnly) ? null : _pickValidUntil,
                  icon: const Icon(Icons.event_rounded),
                  label: Text(
                    _validUntil == null
                        ? 'Set Valid Until'
                        : AppDateTime.formatDate(
                            context, localePrefs, _validUntil),
                  ),
                ),
              ),
              SizedBox(
                width: wide ? 220 : double.infinity,
                child: TextField(
                  controller: _discountCtrl,
                  enabled: !_readOnly,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Header Discount',
                      prefixIcon: Icon(Icons.percent_rounded)),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              SizedBox(
                width: wide ? 480 : double.infinity,
                child: TextField(
                  controller: _notesCtrl,
                  enabled: !_readOnly,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Notes / Terms', alignLabelWithHint: true),
                ),
              ),
              if (_convertedSaleId != null)
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) =>
                            SaleDetailPage(saleId: _convertedSaleId!)),
                  ),
                  child: const Text('Open Converted Sale'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ProfessionalSectionCard(
          title: 'Quote Lines',
          subtitle:
              'Use the same structured line-entry pattern as B2B invoice forms.',
          action: FilledButton.tonalIcon(
            onPressed: (_loading || _readOnly) ? null : _addOrReplaceProduct,
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
                      _QuoteHead(label: 'Item', width: 320),
                      _QuoteHead(label: 'Qty', width: 90),
                      _QuoteHead(label: 'Price', width: 110),
                      _QuoteHead(label: 'Disc %', width: 90),
                      _QuoteHead(label: 'Net', width: 110),
                      _QuoteHead(label: 'Action', width: 70),
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
                              OutlinedButton(
                                onPressed: (_loading || _readOnly)
                                    ? null
                                    : () => _addOrReplaceProduct(line),
                                child:
                                    Text(line.hasProduct ? 'Change' : 'Select'),
                              ),
                            ],
                          ),
                        ),
                        _QuoteNumCell(
                            controller: line.quantityCtrl,
                            width: 90,
                            enabled: !_readOnly,
                            onChanged: (_) => setState(() {})),
                        _QuoteNumCell(
                            controller: line.priceCtrl,
                            width: 110,
                            enabled: !_readOnly,
                            onChanged: (_) => setState(() {})),
                        _QuoteNumCell(
                            controller: line.discountCtrl,
                            width: 90,
                            enabled: !_readOnly,
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
                          width: 70,
                          child: IconButton(
                            onPressed: (_loading || _readOnly)
                                ? null
                                : () {
                                    setState(() {
                                      line.dispose();
                                      _lines = [..._lines]..remove(line);
                                      if (_lines.isEmpty) {
                                        _lines = [_QuoteLine.empty()];
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
      appBar: AppBar(title: Text(_isEdit ? 'Quote' : 'New Quote')),
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

class _QuoteLine {
  _QuoteLine({
    this.productId,
    this.comboProductId,
    this.productName,
    this.variantName,
    String quantity = '',
    String price = '',
    String discount = '0',
  })  : quantityCtrl = TextEditingController(text: quantity),
        priceCtrl = TextEditingController(text: price),
        discountCtrl = TextEditingController(text: discount);

  factory _QuoteLine.empty() => _QuoteLine();

  factory _QuoteLine.fromProduct(PosProductDto product) => _QuoteLine(
        productId: product.productId > 0 ? product.productId : null,
        comboProductId: product.comboProductId,
        productName: product.name,
        variantName: product.variantName,
        quantity: '1',
        price: product.price.toStringAsFixed(2),
      );

  factory _QuoteLine.fromJson(Map<String, dynamic> json) => _QuoteLine(
        productId: json['product_id'] as int?,
        comboProductId: json['combo_product_id'] as int?,
        productName:
            (json['product_name'] ?? json['product']?['name'] ?? 'Item')
                .toString(),
        variantName: json['variant_name']?.toString(),
        quantity:
            ((json['quantity'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
        price:
            ((json['unit_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
        discount: ((json['discount_percentage'] as num?)?.toDouble() ?? 0)
            .toStringAsFixed(2),
      );

  int? productId;
  int? comboProductId;
  String? productName;
  String? variantName;
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

  void applyProduct(PosProductDto product) {
    productId = product.productId > 0 ? product.productId : null;
    comboProductId = product.comboProductId;
    productName = product.name;
    variantName = product.variantName;
    quantityCtrl.text = '1';
    priceCtrl.text = product.price.toStringAsFixed(2);
    discountCtrl.text = '0';
  }

  Map<String, dynamic> toJson() => {
        if ((productId ?? 0) > 0) 'product_id': productId,
        if ((comboProductId ?? 0) > 0) 'combo_product_id': comboProductId,
        'quantity': quantity,
        'unit_price': unitPrice,
        'discount_percentage': discount,
      };

  void dispose() {
    quantityCtrl.dispose();
    priceCtrl.dispose();
    discountCtrl.dispose();
  }
}

class _QuotePartyBox extends StatelessWidget {
  const _QuotePartyBox(
      {required this.customer, required this.label, required this.onSelect});
  final PosCustomerDto? customer;
  final String label;
  final VoidCallback? onSelect;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFD),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD7E3EF)),
        ),
        child: Row(
          children: [
            Icon(label == 'B2B Party'
                ? Icons.business_rounded
                : Icons.person_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customer?.name ?? label,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            FilledButton.tonal(
                onPressed: onSelect, child: const Text('Select')),
          ],
        ),
      );
}

class _QuoteHead extends StatelessWidget {
  const _QuoteHead({required this.label, required this.width});
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

class _QuoteNumCell extends StatelessWidget {
  const _QuoteNumCell(
      {required this.controller,
      required this.width,
      required this.enabled,
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
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: onChanged,
          ),
        ),
      );
}

class _QuoteBanner extends StatelessWidget {
  const _QuoteBanner({required this.message, required this.color});
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
