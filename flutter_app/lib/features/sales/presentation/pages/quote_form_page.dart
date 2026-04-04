import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/app_date_time.dart';
import '../../../../core/error_handler.dart';
import '../../../../core/locale_preferences.dart';
import '../../../../shared/widgets/app_selection_dialog.dart';
import '../../../auth/controllers/auth_notifier.dart';
import '../../../customers/data/customer_repository.dart';
import '../../../customers/data/models.dart';
import '../../../dashboard/controllers/location_notifier.dart';
import '../../../pos/data/models.dart';
import '../../../pos/data/pos_repository.dart';
import '../../data/sales_repository.dart';
import '../widgets/document_line_editor_dialog.dart';
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

  DocumentCustomerSnapshot? _customer;
  String _transactionType = 'B2B';
  DateTime? _validUntil;
  List<DocumentLineDraft> _lines = const [];
  bool _loading = false;
  String? _error;
  String? _info;
  bool _readOnly = false;
  int? _convertedSaleId;
  String? _quoteNumber;
  DateTime? _quoteDate;
  String? _status;

  bool get _isEdit => widget.quoteId != null;

  List<DocumentLineDraft> get _activeLines => _lines
      .where(
          (line) => line.hasProduct && line.unitPrice > 0 && line.quantity > 0)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadQuote();
    } else {
      _quoteDate = DateTime.now();
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
      _info = null;
    });
    try {
      final quote =
          await ref.read(salesRepositoryProvider).getQuote(widget.quoteId!);
      final status = quote['status']?.toString() ?? 'DRAFT';
      final convertedSaleId = (quote['converted_sale_id'] as num?)?.toInt();
      final readOnly = convertedSaleId != null || status == 'CONVERTED';
      final customerId = (quote['customer_id'] as num?)?.toInt() ??
          ((quote['customer'] as Map<String, dynamic>?)?['customer_id']
              as int?);
      DocumentCustomerSnapshot? customer;
      if (customerId != null && customerId > 0) {
        try {
          final fullCustomer = await ref
              .read(customerRepositoryProvider)
              .getCustomer(customerId);
          customer = DocumentCustomerSnapshot.fromCustomer(fullCustomer);
        } catch (_) {
          final customerMap = quote['customer'] as Map<String, dynamic>?;
          customer = customerMap == null
              ? null
              : DocumentCustomerSnapshot(
                  customerId: customerId,
                  name: customerMap['name']?.toString() ?? 'Customer',
                  customerType: _transactionType,
                );
        }
      }

      if (!mounted) return;
      setState(() {
        _convertedSaleId = convertedSaleId;
        _readOnly = readOnly;
        _status = status;
        _quoteNumber = quote['quote_number']?.toString();
        _quoteDate = DateTime.tryParse(quote['quote_date']?.toString() ?? '');
        _transactionType =
            normalizeSaleTransactionType(quote['transaction_type']?.toString());
        _customer = customer;
        _validUntil = DateTime.tryParse(quote['valid_until']?.toString() ?? '');
        _discountCtrl.text =
            ((quote['discount_amount'] as num?)?.toDouble() ?? 0)
                .toStringAsFixed(2);
        _notesCtrl.text = quote['notes']?.toString() ?? '';
        _lines = (quote['items'] as List<dynamic>? ?? const [])
            .map((item) =>
                DocumentLineDraft.fromQuoteJson(item as Map<String, dynamic>))
            .where((item) => item.hasProduct)
            .toList(growable: false);
        _info = !_readOnly
            ? null
            : (_convertedSaleId == null
                ? 'This quote is read-only because it has already been converted.'
                : 'This quote is read-only because it has already been converted to sale #$_convertedSaleId.');
      });
    } catch (e) {
      if (mounted) setState(() => _error = ErrorHandler.message(e));
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

  Future<CustomerDto?> _showCustomerDialog() async {
    return showDialog<CustomerDto>(
      context: context,
      builder: (context) {
        final repo = ref.read(customerRepositoryProvider);
        final controller = TextEditingController();
        List<CustomerDto> results = const [];
        bool loading = true;
        bool kickoff = true;
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> runSearch(String query) async {
              loading = true;
              setStateDialog(() {});
              try {
                results = await repo.getCustomers(
                  search: query,
                  customerType: _transactionType,
                );
              } finally {
                loading = false;
                setStateDialog(() {});
              }
            }

            if (kickoff) {
              kickoff = false;
              Future.microtask(() => runSearch(''));
            }

            return AppSelectionDialog(
              title: _transactionType == 'B2B'
                  ? 'Select B2B Party'
                  : 'Select Customer',
              maxWidth: 640,
              loading: loading,
              searchField: TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: _transactionType == 'B2B'
                      ? 'Search parties by name, phone, or email'
                      : 'Search customers',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onChanged: (value) => runSearch(value.trim()),
                onSubmitted: (value) => runSearch(value.trim()),
              ),
              body: results.isEmpty && !loading
                  ? Center(
                      child: Text(
                        _transactionType == 'B2B'
                            ? 'No B2B parties found'
                            : 'No customers found',
                      ),
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final customer = results[index];
                        final details = [
                          if ((customer.contactPerson ?? '').trim().isNotEmpty)
                            customer.contactPerson!.trim(),
                          if ((customer.phone ?? '').trim().isNotEmpty)
                            customer.phone!.trim(),
                          if ((customer.email ?? '').trim().isNotEmpty)
                            customer.email!.trim(),
                        ].join(' • ');
                        return ListTile(
                          title: Text(customer.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (details.isNotEmpty) Text(details),
                              Text(
                                (customer.shippingAddress ??
                                            customer.address ??
                                            'No address on profile')
                                        .trim()
                                        .isEmpty
                                    ? 'No address on profile'
                                    : (customer.shippingAddress ??
                                            customer.address ??
                                            'No address on profile')
                                        .trim(),
                              ),
                            ],
                          ),
                          trailing: Text(
                            customer.creditBalance == 0
                                ? '0.00'
                                : customer.creditBalance.toStringAsFixed(2),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          onTap: () => Navigator.of(context).pop(customer),
                        );
                      },
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickCustomer() async {
    final result = await _showCustomerDialog();
    if (result == null || !mounted) return;
    setState(() {
      _customer = DocumentCustomerSnapshot.fromCustomer(result);
      _error = null;
    });
  }

  Future<List<DocumentProductOption>> _searchProducts(String query) async {
    final products =
        await ref.read(posRepositoryProvider).searchProducts(query);
    return products.map(DocumentProductOption.fromPosProduct).toList();
  }

  Future<void> _editLine({DocumentLineDraft? line, int? index}) async {
    if (_readOnly) return;
    final result = await showDocumentLineEditorDialog(
      context: context,
      ref: ref,
      title: line == null ? 'Add Quote Item' : 'Edit Quote Item',
      initialLine: line?.copy() ?? DocumentLineDraft.empty(),
      searchProducts: _searchProducts,
      allowDelete: line != null,
    );
    if (result == null || !mounted) return;
    setState(() {
      _error = null;
      if (result.remove) {
        if (index != null) {
          _lines = [..._lines]..removeAt(index);
        }
        return;
      }
      final saved = result.line!;
      if (index == null) {
        _lines = [..._lines, saved];
      } else {
        final next = [..._lines];
        next[index] = saved;
        _lines = next;
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
      final repo = ref.read(salesRepositoryProvider);
      final payloadItems =
          items.map((line) => line.toQuoteJson()).toList(growable: false);
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
    final location = ref.watch(locationNotifierProvider).selected;
    final user = ref.watch(authNotifierProvider).user;
    final wide = MediaQuery.of(context).size.width >= 1200;
    final lines = _activeLines;
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final totalQty = lines.fold<double>(0, (sum, line) => sum + line.quantity);
    final discount = double.tryParse(_discountCtrl.text.trim()) ?? 0;
    final total = subtotal - discount;

    final mainColumn = Column(
      children: [
        _buildHeader(localePrefs),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth =
                wide ? (constraints.maxWidth - 32) / 3 : constraints.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(width: cardWidth, child: _buildCustomerCard()),
                SizedBox(width: cardWidth, child: _buildShippingCard()),
                SizedBox(
                  width: cardWidth,
                  child: _buildMetadataCard(
                      localePrefs, location?.name, user?.username),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _buildLinesCard(lines, totalQty),
      ],
    );

    final sideColumn = Column(
      children: [
        _buildAccountCard(),
        const SizedBox(height: 16),
        _buildNotesCard(),
        const SizedBox(height: 16),
        _buildSummaryCard(lines.length, totalQty, subtotal, discount, total),
      ],
    );

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Quote' : 'New Quote')),
      body: SafeArea(
        child: _loading && _isEdit
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: mainColumn),
                        const SizedBox(width: 16),
                        SizedBox(width: 340, child: sideColumn),
                      ],
                    )
                  else ...[
                    mainColumn,
                    const SizedBox(height: 16),
                    sideColumn,
                  ],
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(LocalePreferencesState localePrefs) {
    return Column(
      children: [
        ProfessionalDocumentHeader(
          title: _isEdit
              ? (_readOnly ? 'Quote (Read-only)' : 'Edit Quote')
              : 'New Quote',
          subtitle:
              'Structure the quote like a business document: customer and shipping context at the top, a click-to-edit item table in the middle, and a persistent decision rail on the right.',
          badges: [
            ProfessionalBadge(
              label: _transactionType == 'B2B' ? 'B2B Quote' : 'Retail Quote',
            ),
            if ((_status ?? '').trim().isNotEmpty)
              ProfessionalBadge(
                label: 'Status: ${_status!}',
                backgroundColor: const Color(0xFFE8F3EC),
                foregroundColor: const Color(0xFF255C35),
              ),
            if (_validUntil != null)
              ProfessionalBadge(
                label:
                    'Valid ${AppDateTime.formatDate(context, localePrefs, _validUntil)}',
                backgroundColor: const Color(0xFFF8EEDC),
                foregroundColor: const Color(0xFF7B5416),
              ),
            if (_readOnly)
              const ProfessionalBadge(
                label: 'Read-only',
                backgroundColor: Color(0xFFFDE8E4),
                foregroundColor: Color(0xFF8A3E31),
              ),
          ],
        ),
        if ((_error ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _Banner(
            message: _error!,
            color: Theme.of(context).colorScheme.errorContainer,
          ),
        ],
        if ((_info ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          _Banner(message: _info!, color: const Color(0xFFE7F0FA)),
        ],
      ],
    );
  }

  Widget _buildCustomerCard() {
    final customer = _customer;
    return _OverviewCard(
      title: 'Customer Information',
      icon: Icons.person_outline_rounded,
      action: FilledButton.tonalIcon(
        onPressed: (_loading || _readOnly) ? null : _pickCustomer,
        icon: const Icon(Icons.search_rounded),
        label: Text(customer == null ? 'Select' : 'Change'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HighlightPanel(
            title: customer?.name ??
                (_transactionType == 'B2B'
                    ? 'Select a B2B party'
                    : 'Optional retail customer'),
            subtitle: customer == null
                ? 'Attach the party for billing, contact, and terms context.'
                : [
                    if (customer.identityChips.isNotEmpty)
                      customer.identityChips.join(' • '),
                    if ((customer.taxNumber ?? '').trim().isNotEmpty)
                      'Tax ${customer.taxNumber!.trim()}',
                  ].join(' • '),
          ),
          if (customer != null) ...[
            const SizedBox(height: 14),
            _FieldPair(label: 'Customer Type', value: customer.customerType),
            _FieldPair(
              label: 'Credit Balance',
              value: customer.creditBalance.toStringAsFixed(2),
            ),
            if (customer.paymentTerms > 0)
              _FieldPair(
                label: 'Payment Terms',
                value: '${customer.paymentTerms} days',
              ),
          ],
          if (customer != null && !_readOnly) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => setState(() => _customer = null),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Clear Customer'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShippingCard() {
    final customer = _customer;
    return _OverviewCard(
      title: 'Shipping Details',
      icon: Icons.local_shipping_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HighlightPanel(
            title: customer?.primaryAddress ??
                'Shipping address appears after customer selection',
            subtitle: customer == null
                ? 'Use the selected customer profile to populate the delivery or billing address context.'
                : ((customer.shippingAddress ?? '').trim().isNotEmpty
                    ? 'Pulled from the customer shipping address.'
                    : 'Using the customer billing address because no separate shipping address is set.'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataCard(
    LocalePreferencesState localePrefs,
    String? locationName,
    String? username,
  ) {
    return _OverviewCard(
      title: 'Document Metadata',
      icon: Icons.description_outlined,
      child: Column(
        children: [
          _FieldPair(
            label: 'Quote Number',
            value: (_quoteNumber ?? '').trim().isEmpty
                ? 'Auto-generated on save'
                : _quoteNumber!,
          ),
          _FieldPair(
            label: 'Quote Date',
            value: AppDateTime.formatDate(context, localePrefs, _quoteDate),
          ),
          _FieldPair(
            label: 'Quote Type',
            value: _transactionType,
            trailing: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _transactionType,
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
                items: const [
                  DropdownMenuItem(value: 'B2B', child: Text('B2B')),
                  DropdownMenuItem(value: 'RETAIL', child: Text('Retail')),
                ],
              ),
            ),
          ),
          _FieldPair(
            label: 'Valid Until',
            value: _validUntil == null
                ? 'Not set'
                : AppDateTime.formatDate(context, localePrefs, _validUntil),
            trailing: TextButton.icon(
              onPressed: (_loading || _readOnly) ? null : _pickValidUntil,
              icon: const Icon(Icons.event_rounded),
              label: Text(_validUntil == null ? 'Set' : 'Change'),
            ),
          ),
          _FieldPair(
            label: 'Location',
            value: (locationName ?? '').trim().isEmpty
                ? 'No location selected'
                : locationName!,
          ),
          _FieldPair(
            label: 'Prepared By',
            value: (username ?? '').trim().isEmpty ? 'Current user' : username!,
          ),
          if (_convertedSaleId != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SaleDetailPage(saleId: _convertedSaleId!),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open Converted Sale'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLinesCard(List<DocumentLineDraft> lines, double totalQty) {
    return ProfessionalSectionCard(
      title: 'Quote Items',
      subtitle:
          'Add items through the dedicated dialog. Tap any row to update quantity, price, or discount.',
      action: FilledButton.tonalIcon(
        onPressed: (_loading || _readOnly) ? null : () => _editLine(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Item'),
      ),
      child: lines.isEmpty
          ? _EmptyLines(
              readOnly: _readOnly,
              onAdd: (_loading || _readOnly) ? null : () => _editLine(),
            )
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _QuoteTableHeader(),
                      const SizedBox(height: 10),
                      for (var index = 0; index < lines.length; index++) ...[
                        _QuoteTableRow(
                          index: index + 1,
                          line: lines[index],
                          enabled: !_readOnly,
                          onTap: () =>
                              _editLine(line: lines[index], index: index),
                          onDelete: _readOnly
                              ? null
                              : () => setState(
                                    () => _lines = [..._lines]..removeAt(index),
                                  ),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed:
                          (_loading || _readOnly) ? null : () => _editLine(),
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Add New Item'),
                    ),
                    const Spacer(),
                    Text(
                      'Items: ${lines.length}    Total Qty: ${formatDocumentQuantity(totalQty)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildAccountCard() {
    final customer = _customer;
    return ProfessionalSectionCard(
      title: 'Customer Exposure',
      child: customer == null
          ? Text(
              'Select a customer to review credit balance, credit limit, and payment terms before finalizing the quote.',
              style: Theme.of(context).textTheme.bodyMedium,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.creditBalance.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFBA1A1A),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Current outstanding balance',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 14),
                _PreviewRow(
                  label: 'Credit Limit',
                  value: customer.creditLimit.toStringAsFixed(2),
                ),
                const SizedBox(height: 10),
                _PreviewRow(
                  label: 'Payment Terms',
                  value: customer.paymentTerms > 0
                      ? '${customer.paymentTerms} days'
                      : 'Not set',
                ),
                const SizedBox(height: 10),
                _PreviewRow(
                  label: 'Address',
                  value: customer.primaryAddress,
                ),
              ],
            ),
    );
  }

  Widget _buildNotesCard() {
    return ProfessionalSectionCard(
      title: 'Quote Notes',
      subtitle:
          'Use this area for commercial terms, delivery notes, or any wording that should travel with the quote.',
      child: TextField(
        controller: _notesCtrl,
        enabled: !_readOnly,
        maxLines: 6,
        decoration: const InputDecoration(
          labelText: 'Terms / Notes',
          alignLabelWithHint: true,
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    int itemCount,
    double totalQty,
    double subtotal,
    double discount,
    double total,
  ) {
    return ProfessionalSummaryCard(
      title: 'Quote Summary',
      rows: [
        (label: 'Items', value: '$itemCount', emphasize: false),
        (
          label: 'Total Qty',
          value: formatDocumentQuantity(totalQty),
          emphasize: false,
        ),
        (
          label: 'Line Net',
          value: subtotal.toStringAsFixed(2),
          emphasize: false,
        ),
        (
          label: 'Header Discount',
          value: discount.toStringAsFixed(2),
          emphasize: false,
        ),
      ],
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFDE8E4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quoted Total',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  total.toStringAsFixed(2),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFBA1A1A),
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'The backend will finalize taxes and totals from product pricing rules when the quote is saved.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: (_loading || _readOnly) ? null : _submit,
            icon: const Icon(Icons.request_quote_rounded),
            label: Text(
              _readOnly
                  ? 'Read-only'
                  : (_isEdit ? 'Update Quote' : 'Create Quote'),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.title,
    required this.icon,
    this.action,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget? action;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFFBA1A1A), width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(icon, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (action != null) ...[
                    const SizedBox(width: 12),
                    action!,
                  ],
                ],
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightPanel extends StatelessWidget {
  const _HighlightPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldPair extends StatelessWidget {
  const _FieldPair({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _QuoteTableHeader extends StatelessWidget {
  const _QuoteTableHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          _HeaderCell(label: '#', width: 50),
          _HeaderCell(label: 'Barcode', width: 140),
          _HeaderCell(label: 'Item / Description', width: 320),
          _HeaderCell(label: 'Qty', width: 90),
          _HeaderCell(label: 'Price', width: 110),
          _HeaderCell(label: 'Disc %', width: 90),
          _HeaderCell(label: 'Total', width: 120),
          _HeaderCell(label: 'Action', width: 80),
        ],
      ),
    );
  }
}

class _QuoteTableRow extends StatelessWidget {
  const _QuoteTableRow({
    required this.index,
    required this.line,
    required this.enabled,
    required this.onTap,
    this.onDelete,
  });

  final int index;
  final DocumentLineDraft line;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              _BodyCell(label: '$index', width: 50),
              _BodyCell(
                label:
                    (line.barcode ?? '').trim().isEmpty ? '-' : line.barcode!,
                width: 140,
              ),
              _BodyCell(
                label: line.displayName,
                secondary: line.supportingText,
                width: 320,
              ),
              _BodyCell(
                label: formatDocumentQuantity(line.quantity),
                width: 90,
              ),
              _BodyCell(
                label: line.unitPrice.toStringAsFixed(2),
                width: 110,
              ),
              _BodyCell(
                label: line.discountPercent.toStringAsFixed(2),
                width: 90,
              ),
              _BodyCell(
                label: line.lineTotal.toStringAsFixed(2),
                width: 120,
                emphasize: true,
              ),
              SizedBox(
                width: 80,
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Edit',
                      onPressed: enabled ? onTap : null,
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(
                      tooltip: 'Delete',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
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
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, required this.width});

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({
    required this.label,
    required this.width,
    this.secondary,
    this.emphasize = false,
  });

  final String label;
  final double width;
  final String? secondary;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: emphasize
                ? Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
          ),
          if ((secondary ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              secondary!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyLines extends StatelessWidget {
  const _EmptyLines({required this.readOnly, required this.onAdd});

  final bool readOnly;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_rounded, size: 36),
          const SizedBox(height: 12),
          Text(
            readOnly ? 'No quote items available.' : 'No items added yet.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            readOnly
                ? 'This quote does not contain any active lines.'
                : 'Use the item dialog to search by barcode or product name and build the quote one line at a time.',
            textAlign: TextAlign.center,
          ),
          if (!readOnly) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add First Item'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}
